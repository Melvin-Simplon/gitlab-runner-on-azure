##@ Setup

bootstrap: ## Create the CI identity and the access rights (once)
	@$(MAKE) --no-print-directory bootstrap-ci
	@$(MAKE) --no-print-directory bootstrap-access
	@$(MAKE) --no-print-directory ci-vars

bootstrap-ci: ## Managed identity trusted by GitLab CI (OIDC, main only)
	@scripts/bootstrap-ci-identity.sh

bootstrap-access: ## Azure roles for the admins and the CI
	@scripts/bootstrap-access.sh

grant-aks: ## Give someone admin access to AKS: make grant-aks UPN=prenom.ext@simplonformations.co
	@scripts/bootstrap-access.sh --user "$(UPN)"

ci-vars: ## Push the Azure identifiers to the GitLab CI/CD variables
	@scripts/ci-variables.sh
