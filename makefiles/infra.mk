##@ Infra

plan: ## Show what Terraform would change (infra, then ArgoCD)
	@scripts/tf.sh infra plan
	@scripts/tf.sh bootstrap plan

up: ## Create or update AKS, then ArgoCD, then the runner token
	@scripts/tf.sh infra apply
	@scripts/tf.sh bootstrap apply
	@$(MAKE) --no-print-directory kubeconfig
	@$(MAKE) --no-print-directory runner-secret

destroy: ## Remove ArgoCD, then AKS
	@scripts/tf.sh bootstrap destroy
	@scripts/tf.sh infra destroy
