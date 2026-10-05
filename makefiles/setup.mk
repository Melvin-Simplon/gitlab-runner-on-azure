##@ Setup

bootstrap: ## Grant the Azure access rights (once)
	@$(MAKE) --no-print-directory bootstrap-access

bootstrap-access: ## Azure roles for the cluster admins
	@scripts/bootstrap-access.sh

grant-aks: ## Give someone admin access to AKS: make grant-aks UPN=prenom.ext@simplonformations.co
	@scripts/bootstrap-access.sh --user "$(UPN)"
