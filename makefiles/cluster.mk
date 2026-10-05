##@ Cluster

start: ## Start the stopped cluster
	@scripts/cluster.sh start

stop: ## Stop the cluster (nodes are no longer billed)
	@scripts/cluster.sh stop

kubeconfig: ## Get kubectl access with your Entra account
	@scripts/cluster.sh kubeconfig

argocd-ui: ## Open the ArgoCD UI on https://localhost:8080
	@scripts/argocd-ui.sh
