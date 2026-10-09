# GitLab Runners on AKS: summary

## 1. The project

A Kubernetes cluster on Azure that runs **GitLab CI jobs**.

It is **watched**, **backed up**, and **fully described as code**.

## 2. Azure side (Terraform)

- An **AKS** cluster with **2 Standard_D2s_v3 nodes** (4 vCPU in total, because the class shares the quota).
- **3 Terraform stacks**:
  - `backup`: the backup storage, which survives the deletion of the cluster.
  - `infra`: the AKS cluster and the Azure identities.
  - `bootstrap`: ArgoCD and the root app.
- The Terraform state is **stored in GitLab**.

## 3. Deployment (GitOps with ArgoCD)

- ArgoCD reads the `k8s/apps/` folder of the repository: **one file per app**.
- To change the cluster, open a **merge request**. Once merged, ArgoCD applies it within **30 seconds**.
- `main` is **protected**: no direct push, merge requests only.

## 4. The GitLab Runner

- It takes the jobs from GitLab.com and runs **each job in a Kubernetes pod**.
- **2 jobs at a time**, each one limited to **1 CPU and 1 GB** of memory.
- It only takes jobs with its tags: `linux`, `ubuntu`, `x64`.
- The [test-runner](https://gitlab.com/WhiteMuush/test-runner) project tests it with 2 stress jobs that run together:
  - CPU, 700 MB of memory, and an artifact upload to GitLab;
  - node disk, and a 100 MB download.
- Result: about **30 seconds** per pipeline, instead of 5 minutes for the first version.

## 5. Observability

- **Metrics**: a VictoriaMetrics cluster, kept **35 days**, collected by **vmagent** on each node.
- The runner has its own **vmagent sidecar**, which sends its metrics.
- **Logs**: VictoriaLogs, kept **7 days**, for every pod, `kube-system` included.
- **Alerts**: **23 rules** (nodes, pods, platform, backups, runner SLOs), grouped by Alertmanager. They show in Grafana, menu **Alerting**, and with `make alerts`.
- **Grafana** over **HTTPS**, behind Traefik, with a Let's Encrypt certificate managed by cert-manager.
- Dashboards in **3 folders**: Kubernetes, Observability, Platform.
- The Platform folder holds the **Gitlab Runner** and **Runner SLO** dashboards.

## 6. Runner SLOs

The **Runner SLO** dashboard answers one question:

> Do we have working runners, all the time?

Each SLO is measured over the **last 30 days**, continuously. VictoriaMetrics keeps 35 days of metrics.

| SLO | Target over 30 days | Measured on day 1 |
|---|---|---|
| Runner is reachable | 99 % | 99.88 % |
| Runner talks to GitLab | 99 % | 100 % |
| Jobs are not broken by the runner | 99 % | 100 % |
| Jobs start within 60 seconds | 95 % | 71 % |

Each SLO shows 3 numbers:

- **SLI**: the current score.
- **Error budget left**: the margin before the target is missed.
- **Burn rate**: how fast the budget goes.

The **71 %** is a real result: a 9-job pipeline filled the 2 runner slots, and 6 jobs waited more than 60 seconds. The SLOs showed a **capacity limit**.

Following the Google SRE practice:

- **Synthetic traffic**: the test-runner project runs a pipeline every 15 minutes during work hours, so the job SLOs have enough events.
- **Recording rules**: vmalert computes each SLO over 7 windows, from 5 minutes to 30 days.
- **Burn rate alerts**: 8 alerts, each one on a long and a short window.
- **No data counts as down**: if the runner disappears while the cluster runs, the minute is bad.
- **Error budget policy**: below 0, only reliability fixes are merged.
- Everything is written in `docs/slo.md`.

## 7. Backups

- **Velero** saves every resource of the cluster **every 6 hours**.
- Each backup is kept **7 days**.
- It is the only way to get back the secrets that are not in Git: the runner token and the Grafana password.

## 8. Security

- **No Azure key**: Velero and the exporter log in with **Workload Identity**.
- **Least privilege**: each component only has the rights it needs.
- **No secret in Git**: they go through `.env` and `make`.
- People log in to the cluster with their **Entra ID account**, without an admin kubeconfig.

## 9. Daily use

Everything goes through **`make`**:

| Command | Role |
|---|---|
| `make up` | Creates or updates the whole platform |
| `make start` / `make stop` | Starts or stops the cluster |
| `make status` | Checks everything in one pass |
| `make alerts` | Lists the alerts that fire now |
| `make backups` | Lists the backups |

`make` alone opens an **interactive menu**.

## 10. A real incident

1. The nodes went **NotReady**, and Grafana and ArgoCD stopped answering.
2. The investigation showed that the machines were **stopped**, while AKS still said "Running".
3. The cause: the **school Azure subscription** had become **read only**.
4. Once it was enabled again, `make start` started the cluster.
5. Everything came back **on its own, thanks to ArgoCD**.

## 11. Limits and next steps

- **Only 2 job slots**: a big pipeline makes jobs wait. In production, the runners would get their own node pool with autoscaling.
- The job SLOs only measure work hours, because the cluster is stopped at night.
- Traffic between pods is plain **HTTP**, not encrypted.
