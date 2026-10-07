##@ Status

status: ## Check the whole platform in one pass, in color
	@scripts/status.sh

alerts: ## List the alerts that fire now
	@scripts/alerts.sh

backups: ## List the Velero backups, newest first
	@scripts/backups.sh

top: ## CPU and memory of the nodes and of the hungriest pods
	@scripts/top.sh
