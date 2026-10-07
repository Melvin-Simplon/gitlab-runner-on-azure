##@ Infra

plan: ## Show what Terraform would change (backups, infra, then ArgoCD)
	@scripts/tf.sh backup plan
	@scripts/tf.sh infra plan
	@scripts/tf.sh bootstrap plan

up: ## Create or update the backup storage, AKS, ArgoCD, then the runner and Grafana secrets
	@scripts/tf.sh backup apply
	@scripts/tf.sh infra apply
	@scripts/tf.sh bootstrap apply
	@$(MAKE) --no-print-directory kubeconfig
	@$(MAKE) --no-print-directory runner-secret
	@$(MAKE) --no-print-directory grafana-secret

destroy: ## Remove ArgoCD, then AKS, then the backups if you say so
	@scripts/tf.sh bootstrap destroy
	@scripts/tf.sh infra destroy
	@scripts/tf.sh backup destroy
