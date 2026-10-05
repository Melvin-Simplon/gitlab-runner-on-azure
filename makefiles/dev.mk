##@ Dev

help: ## List the targets
	@scripts/help.sh $(MAKEFILE_LIST)

lint: ## terraform fmt/validate, tflint, shellcheck
	@scripts/lint.sh

.PHONY: help lint bootstrap bootstrap-ci bootstrap-access grant-aks ci-vars \
	plan up destroy start stop kubeconfig argocd-ui
