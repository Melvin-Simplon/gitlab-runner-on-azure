##@ Infra

plan: ## Show what Terraform would change (infra, then ArgoCD)
	@scripts/tf.sh infra plan
	@scripts/tf.sh bootstrap plan

up: ## Create or update AKS, then ArgoCD
	@scripts/tf.sh infra apply
	@scripts/tf.sh bootstrap apply

destroy: ## Remove ArgoCD, then AKS
	@scripts/tf.sh bootstrap destroy
	@scripts/tf.sh infra destroy
