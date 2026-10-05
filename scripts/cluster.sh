#!/usr/bin/env bash
# Day-to-day cluster operations: cluster.sh <start|stop|kubeconfig>
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

require_env AZ_SUBSCRIPTION_ID AZ_RESOURCE_GROUP CLUSTER_NAME
require_cmd az

[[ $# -eq 1 ]] || die "usage: cluster.sh <start|stop|kubeconfig>"
readonly ACTION=$1

# ensure_power <Running|Stopped> <az aks verb>
ensure_power() {
    local wanted=$1 verb=$2 state
    task "cluster : ${verb}"
    state=$(cluster_state)
    if [[ "${state}" == "absent" ]]; then
        skipped "${CLUSTER_NAME}" "no cluster"
    elif [[ "${state}" == "${wanted}" ]]; then
        ok "${CLUSTER_NAME}" "already ${wanted}"
    else
        info "${verb} in progress, this takes a few minutes..."
        azs aks "${verb}" -g "${AZ_RESOURCE_GROUP}" -n "${CLUSTER_NAME}" -o none
        changed "${CLUSTER_NAME}" "${wanted}"
    fi
}

ensure_kubeconfig() {
    task "cluster : kubeconfig"
    require_cmd kubelogin kubectl
    [[ "$(cluster_state)" == "Running" ]] || die "cluster ${CLUSTER_NAME} is not running"
    azs aks get-credentials -g "${AZ_RESOURCE_GROUP}" -n "${CLUSTER_NAME}" --overwrite-existing -o none 2>>"${LOG_FILE}"
    # Reuse the az CLI session instead of an interactive device-code login.
    kubelogin convert-kubeconfig -l azurecli
    kubectl get nodes -o name >/dev/null || die "kubectl gets no answer, check the roles (make bootstrap)"
    ok "${CLUSTER_NAME}" "kubectl context ready"
}

main() {
    log_init "cluster ${ACTION}"
    recap_keys ok changed skipped
    case "${ACTION}" in
        start)      ensure_power Running start ;;
        stop)       ensure_power Stopped stop ;;
        kubeconfig) ensure_kubeconfig ;;
        *)          die "unknown action: ${ACTION}" ;;
    esac
    recap cluster
}

main "$@"
