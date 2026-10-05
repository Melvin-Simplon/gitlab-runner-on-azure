#!/usr/bin/env bash
# Grants the Azure roles: cluster admin for people, deploy rights for the CI.
# Roles sit on the resource group, so they survive a cluster destroy/recreate. Idempotent.
# bootstrap-access.sh               everything: admins from CLUSTER_ADMINS, CI
# bootstrap-access.sh --user <upn>  cluster access for one person only
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

require_env AZ_SUBSCRIPTION_ID AZ_RESOURCE_GROUP
require_cmd az

readonly ROLE_AKS_ADMIN="Azure Kubernetes Service RBAC Cluster Admin"
readonly ROLE_AKS_USER="Azure Kubernetes Service Cluster User Role"

# ensure_role <principal_id> <principal_type> <role> <scope> <label>
ensure_role() {
    local id=$1 type=$2 role=$3 scope=$4 label=$5 count
    # Filter on principalId: no Graph lookup, works right after the identity is created.
    count=$(azs role assignment list --scope "${scope}" --role "${role}" \
        --query "length([?principalId=='${id}'])" -o tsv)
    if (( count > 0 )); then
        ok "${label}" "${role}"
    else
        azs role assignment create --assignee-object-id "${id}" --assignee-principal-type "${type}" \
            --role "${role}" --scope "${scope}" -o none
        changed "${label}" "${role}"
    fi
}

grant_people() {
    task "access : cluster admins"
    local upn id
    for upn in ${CLUSTER_ADMINS}; do
        id=$(az ad user show --id "${upn}" --query id -o tsv)
        ensure_role "${id}" User "${ROLE_AKS_ADMIN}" "${RG_SCOPE}" "${upn}"
        ensure_role "${id}" User "${ROLE_AKS_USER}" "${RG_SCOPE}" "${upn}"
    done
}

grant_ci() {
    task "access : CI identity"
    local id
    id=$(azs identity show -g "${AZ_RESOURCE_GROUP}" -n "${CI_IDENTITY}" --query principalId -o tsv)
    ensure_role "${id}" ServicePrincipal "Contributor" "${RG_SCOPE}" "${CI_IDENTITY}"
    ensure_role "${id}" ServicePrincipal "${ROLE_AKS_ADMIN}" "${RG_SCOPE}" "${CI_IDENTITY}"
}

main() {
    log_init "bootstrap-access $*"
    recap_keys ok changed
    RG_SCOPE=$(azs group show -n "${AZ_RESOURCE_GROUP}" --query id -o tsv)
    readonly RG_SCOPE
    if [[ "${1:-}" == "--user" ]]; then
        [[ -n "${2:-}" ]] || die "usage: make grant-aks UPN=prenom.ext@simplonformations.co"
        CLUSTER_ADMINS=$2
        grant_people
    else
        require_env CI_IDENTITY CLUSTER_ADMINS
        grant_people
        grant_ci
    fi
    recap access
}

main "$@"
