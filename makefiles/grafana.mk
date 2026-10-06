##@ Grafana

grafana-secret: ## Create the Grafana admin password once (kept afterwards)
	@scripts/grafana-secret.sh create

grafana-password: ## Show the Grafana URL, login and password
	@scripts/grafana-secret.sh show
