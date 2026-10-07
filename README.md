# gitlab-runner-on-azure

Production-ready Kubernetes cluster on Azure hosting GitLab CI runners, with a full observability stack (metrics, logs, dashboards, alerts), Velero backups and SLOs.

## Repositories

- **GitLab** (main repository, merge requests, CI): https://gitlab.com/WhiteMuush/gitlab-runner-on-azure
- **GitHub** (copy): https://github.com/Melvin-Simplon/gitlab-runner-on-azure

## Documentation

- [Project brief](docs/consignes.md)
- [VictoriaMetrics Helm charts](https://docs.victoriametrics.com/helm/)
- [vmagent](https://docs.victoriametrics.com/victoriametrics/vmagent/)
- [Traefik](https://doc.traefik.io/traefik/)
- [Grafana](https://grafana.com/docs/grafana/latest/)
- [cert-manager](https://cert-manager.io/docs/)
- [node-exporter](https://github.com/prometheus/node_exporter)
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)
- [Kubernetes system metrics (kubelet, cAdvisor)](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/)
- [Velero](https://velero.io/docs/)
- [Velero plugin for Microsoft Azure](https://github.com/vmware-tanzu/velero-plugin-for-microsoft-azure)
- [AKS Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)
- [azure-metrics-exporter](https://github.com/webdevops/azure-metrics-exporter)
- [Azure Monitor supported metrics](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/supported-metrics/metrics-index)
- [VictoriaLogs](https://docs.victoriametrics.com/victorialogs/)
- [VictoriaLogs collector (vlagent)](https://docs.victoriametrics.com/victorialogs/vlagent/)
- [VictoriaLogs Grafana plugin](https://docs.victoriametrics.com/victorialogs/integrations/grafana/)
- [vmalert](https://docs.victoriametrics.com/victoriametrics/vmalert/)
- [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)

## Contributing

`main` is protected:

1. Create a branch from `main`
2. Open a merge request on GitLab
3. Resolve every discussion, then merge (Maintainers only)

Direct pushes and force pushes to `main` are blocked.
