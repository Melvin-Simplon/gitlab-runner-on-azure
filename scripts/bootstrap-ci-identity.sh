#!/usr/bin/env bash
# Creates the managed identity used by the GitLab CI, trusted through OIDC for the main branch only. Idempotent.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

require_env AZ_SUBSCRIPTION_ID AZ_RESOURCE_GROUP AZ_LOCATION CI_IDENTITY GITLAB_PROJECT
require_cmd az

readonly FEDERATED_NAME="gitlab-main"
readonly FEDERATED_SUBJECT="project_path:${GITLAB_PROJECT}:ref_type:branch:ref:main"

ensure_identity() {
    task "ci : managed identity"
    if azs identity show -g "${AZ_RESOURCE_GROUP}" -n "${CI_IDENTITY}" -o none 2>/dev/null; then
        ok "${CI_IDENTITY}" "already exists"
    else
        azs identity create -g "${AZ_RESOURCE_GROUP}" -n "${CI_IDENTITY}" -l "${AZ_LOCATION}" -o none
        changed "${CI_IDENTITY}" "created"
    fi
}

ensure_federated_credential() {
    task "ci : OIDC trust for gitlab.com"
    local subject
    subject=$(azs identity federated-credential show -g "${AZ_RESOURCE_GROUP}" \
        --identity-name "${CI_IDENTITY}" -n "${FEDERATED_NAME}" --query subject -o tsv 2>/dev/null || true)
    if [[ "${subject}" == "${FEDERATED_SUBJECT}" ]]; then
        ok "${FEDERATED_NAME}" "${subject}"
        return
    fi
    azs identity federated-credential create -g "${AZ_RESOURCE_GROUP}" \
        --identity-name "${CI_IDENTITY}" -n "${FEDERATED_NAME}" \
        --issuer "https://gitlab.com" --subject "${FEDERATED_SUBJECT}" \
        --audiences "api://AzureADTokenExchange" -o none
    changed "${FEDERATED_NAME}" "${FEDERATED_SUBJECT}"
}

main() {
    log_init "bootstrap-ci-identity"
    recap_keys ok changed
    ensure_identity
    ensure_federated_credential
    recap ci-identity
}

main "$@"
