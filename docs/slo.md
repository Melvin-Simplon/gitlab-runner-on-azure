# Runner SLOs

This document defines the service level objectives (SLOs) of the GitLab Runner, how they are measured, how they alert, and what we do when they are missed.

## The service and its users

**The service**: the GitLab Runner `own-runner`, which runs CI jobs as pods in the AKS cluster.

**The users**: the developers who push code and wait for their pipelines.

**The question the SLOs answer**: do we have working runners, all the time?

A developer is hurt when:

1. the runner is down, so no job runs at all;
2. the runner cannot talk to GitLab, so it cannot take jobs;
3. a job fails because of the runner, not because of the code;
4. a job waits too long before it starts.

Each point gives one SLO.

## The SLOs

All objectives are measured over a **rolling window of 30 days**. VictoriaMetrics keeps 35 days of metrics, which covers the window with a margin.

| SLO | SLI: good events / all events | Objective | Error budget over 30 days |
|---|---|---|---|
| `runner-reachable` | Minutes where the runner answers / minutes where the cluster runs | 99 % | about 7 hours down |
| `runner-api` | Runner calls to the GitLab API without a 5xx error / all calls | 99 % | 1 % of calls |
| `runner-jobs-success` | Jobs not failed by the runner / all jobs | 99 % | 1 % of jobs |
| `runner-jobs-start` | Jobs that waited less than 60 seconds / all jobs | 95 % | 5 % of jobs |

### runner-reachable

- **Measured by** vmalert, every minute: `max(up{job="gitlab-runner"}) or vector(0)`, recorded as `slo:runner_up:max`.
- **No data counts as down.** If the runner pod is missing while the cluster runs, its sidecar sends nothing, and the minute counts as bad.
- **Why**: a check from inside the runner pod cannot see that the pod is gone.

### runner-api

- **Measured by** `gitlab_runner_api_request_statuses_total`, counted by the runner itself.
- **Bad event**: a call that gets a `5xx` status.
- **Why**: if the runner cannot reach GitLab, no job can start, even when the pod looks fine.

### runner-jobs-success

- **Measured by** `gitlab_runner_failed_jobs_total` and `gitlab_runner_jobs_total`.
- **Bad event**: a failed job, except `script_failure` (the code of the job failed) and `job_canceled` (someone canceled it).
- **Why**: a failing test is the developer's problem. A runner system failure, a timeout or an image that cannot be pulled is ours.

### runner-jobs-start

- **Measured by** the `gitlab_runner_job_queue_duration_seconds` histogram, which has a bucket at exactly 60 seconds.
- **Bad event**: a job that waited more than 60 seconds before a runner took it.
- **Why**: the runner takes 2 jobs at a time. This SLO shows when that is not enough.

## How it is built

1. **Synthetic traffic.** The [test-runner](https://gitlab.com/WhiteMuush/test-runner) project runs a pipeline of 2 jobs every hour, Monday to Friday, from 8:00 to 17:00 (Paris time). That is about 440 jobs over 30 days. Without it, there would be too few jobs, and one slow job would move an SLO by several points. GitLab.com Free allows 24 runs per schedule and per day, so one run per hour is the most a schedule can do.
2. **Recording rules.** vmalert computes the error ratio of each SLO over 8 windows (5m, 30m, 1h, 2h, 6h, 1d, 3d, 30d), every minute, as `slo:sli_error:ratio_rate<window>{slo="..."}`. The rules are in `k8s/vmalert/rules.yaml`.
3. **Dashboard.** The **Runner SLO** dashboard in Grafana, folder Platform, reads the recording rules. It shows the SLI over 30 days, the error budget left, the burn rate, and the SLI of the last day.
4. **Alerts.** The burn rate alerts below read the same recording rules.

## Alerts

The **burn rate** says how fast the error budget goes. A burn rate of 1 uses the whole budget in exactly 30 days.

Each alert checks a long window and a short window. The long one proves the problem is real. The short one makes the alert stop quickly once the problem is fixed.

| SLO | Severity | Burn rate | Long window | Short window | Budget used when it fires |
|---|---|---|---|---|---|
| `runner-reachable`, `runner-api` | critical | 14.4 | 1h | 5m | 2 % in 1 hour |
| `runner-reachable`, `runner-api` | critical | 6 | 6h | 30m | 5 % in 6 hours |
| `runner-reachable`, `runner-api` | warning | 1 | 3d | 6h | 10 % in 3 days |
| `runner-jobs-success`, `runner-jobs-start` | critical | 3 | 1d | 2h | 10 % in 1 day |
| `runner-jobs-success`, `runner-jobs-start` | warning | 1 | 3d | 6h | 10 % in 3 days |

The two job SLOs use longer windows: with one pipeline per hour, a 5 minute or 1 hour window is often empty, and an alert on an empty window never fires.

The alerts show in Grafana, menu **Alerting**, and with `make alerts`. They do not send mails or messages yet.

### What to do when an alert fires

| Alert | First checks |
|---|---|
| `RunnerReachableBudgetBurn*` | `kubectl get pods -n gitlab-runner`, then the runner logs in Grafana, VictoriaLogs |
| `RunnerApiBudgetBurn*` | [GitLab status page](https://status.gitlab.com/), then the runner logs |
| `RunnerJobsFailBudgetBurn*` | The failed jobs in GitLab and their `failure_reason`, then the job pods |
| `RunnerJobsSlowBudgetBurn*` | The **Gitlab Runner** dashboard: running jobs and queue duration, then the node CPU with `make top` |

## Error budget policy

| Budget left | What we do |
|---|---|
| More than 25 % | Normal work. Changes to the runner and the cluster go on. |
| Between 0 and 25 % | Every change to the runner or the cluster needs a check of the SLO dashboard after the merge. |
| Below 0 | **Freeze**: only fixes for reliability are merged, until the budget is back above 0. A short written review explains what happened. |

A missed objective caused by GitLab.com itself is noted in the review, but it does not trigger the freeze.

## What is not counted

- **Planned stops.** When the cluster is stopped with `make stop`, vmalert is stopped too, so nothing is counted.
- **Nights and weekends** for the job SLOs, because the synthetic pipeline only runs during work hours.
- **Failures of the job code** (`script_failure`) and **canceled jobs** (`job_canceled`).

## Limits

- The recording rules start when they are deployed. Until 30 days have passed, the 30 day window covers less time.
- `runner-reachable` depends on vmalert. If vmalert itself is down while the cluster runs, those minutes are not counted.
- The job SLOs depend on the synthetic pipeline. If its schedule stops, the job SLOs measure only the real jobs.
- The objectives are first guesses. They are reviewed after one month of real data.

## Review

- **Every month**: read the dashboard, compare each SLO with its objective, and decide whether an objective is too loose or too strict.
- **After each freeze**: read the written review and update this document if a definition was wrong.

## References

- [Google SRE workbook: implementing SLOs](https://sre.google/workbook/implementing-slos/)
- [Google SRE workbook: alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
- [Google SRE workbook: error budget policy](https://sre.google/workbook/error-budget-policy/)
