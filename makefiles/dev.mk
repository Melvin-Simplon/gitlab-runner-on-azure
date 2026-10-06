##@ Dev

menu: ## Interactive menu of every target
	@MAKE="$(MAKE)" scripts/menu.sh $(MAKEFILE_LIST)

help: ## List the targets
	@scripts/help.sh $(MAKEFILE_LIST)

lint: ## terraform fmt/validate, tflint, shellcheck
	@scripts/lint.sh

.PHONY: menu help lint bootstrap bootstrap-access grant-aks \
	plan up destroy start stop kubeconfig argocd-ui runner-secret grafana-secret grafana-password
