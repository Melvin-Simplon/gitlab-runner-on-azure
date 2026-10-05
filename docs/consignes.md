# Project brief

## Summary

You are in charge of setting up a "production-ready" Kubernetes cluster for your company.

The cluster will host the GitLab CI runners for every team, so it must be robust: a complete observability stack, backups of the custom resources, alerts, and so on.

You will also be responsible for its maintenance and for reacting quickly to incidents, so you must define the matching, relevant SLOs.

The SLOs will cover the **availability** and **performance** of the GitLab CI runners. You may add others of your choice.

## Requirements

- **1 time-series database (TSDB)**: Grafana Mimir, Thanos or VictoriaMetrics (warning: the TSDB is not allowed to "pull" metrics)
- **N Prometheus Agents** (pull and push, using Remote Write)
- **1 Grafana** reachable from outside the cluster, over HTTPS, behind a reverse proxy
- **1 Velero** (you decide what it must back up)
- **1 GitLab CI runner**
- **1 "test" GitLab project** that uses your runners
- **1 document** presenting your SLOs
- Every other deployed component (cert-manager, ...) must have its metrics collected and usable

## Observability

- Logs of every pod in the cluster, including the `kube-system` namespace
- Azure metrics (Disks, Storage Account, ...)
- Kubernetes node metrics
- Kubernetes pod metrics
- Velero metrics
- GitLab Runner metrics
- Relevant dashboards and alerts

## Other

- Secure communication is preferred, both between pods and with the outside world (TLS, HTTPS)
- New concepts: TSDB cluster, SLI/SLO/SLA, logs
- Any component that exposes useful metrics can be the subject of an SLO
- Do not forget Kubernetes best practices

## Presentation (demo)

A 5 to 10 minute presentation is expected at the end of the brief. It will cover:

1. Your technology choices
2. How the GitLab runners work
3. Your SLOs
