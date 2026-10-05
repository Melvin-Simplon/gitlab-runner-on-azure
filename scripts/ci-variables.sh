#!/usr/bin/env bash
# Publishes the Azure identifiers the CI needs as GitLab CI/CD variables. Identifiers, not secrets. Idempotent.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

require_env AZ_SUBSCRIPTION_ID AZ_RESOURCE_GROUP CI_IDENTITY GITLAB_PROJECT
require_cmd az glab

# ensure_variable <key> <value>
ensure_variable() {
    local key=$1 value=$2 current
    current=$(glab variable get "${key}" -R "${GITLAB_PROJECT}" 2>/dev/null || true)
    if [[ "${current}" == "${value}" ]]; then
        ok "${key}" "up to date"
    elif [[ -z "${current}" ]]; then
        glab variable set "${key}" "${value}" -R "${GITLAB_PROJECT}" >/dev/null
        changed "${key}" "created"
    else
        glab variable update "${key}" "${value}" -R "${GITLAB_PROJECT}" >/dev/null
        changed "${key}" "updated"
    fi
}

main() {
    log_init "ci-variables"
    recap_keys ok changed
    task "gitlab : CI/CD variables"
    local client_id tenant_id
    client_id=$(azs identity show -g "${AZ_RESOURCE_GROUP}" -n "${CI_IDENTITY}" --query clientId -o tsv)
    tenant_id=$(azs account show --query tenantId -o tsv)
    ensure_variable AZURE_CLIENT_ID "${client_id}"
    ensure_variable AZURE_TENANT_ID "${tenant_id}"
    ensure_variable AZ_SUBSCRIPTION_ID "${AZ_SUBSCRIPTION_ID}"
    recap ci-variables
}

main "$@"
