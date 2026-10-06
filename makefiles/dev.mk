##@ Dev

help: ## List the targets
	@scripts/help.sh $(MAKEFILE_LIST)

lint: ## terraform fmt/validate, tflint, shellcheck
	@scripts/lint.sh

.PHONY: help lint bootstrap bootstrap-access grant-aks \
	plan up destroy start stop kubeconfig argocd-ui runner-secret grafana-secret grafana-password
