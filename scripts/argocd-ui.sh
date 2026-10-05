#!/usr/bin/env bash
# Opens the ArgoCD UI on https://localhost:8080 until an ingress exists (phase 2).
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

require_env CLUSTER_NAME
require_cmd kubectl
readonly PORT="${ARGOCD_PORT:-8080}"

check_context() {
    local context
    context=$(kubectl config current-context 2>/dev/null || true)
    [[ "${context}" == "${CLUSTER_NAME}" ]] \
        || die "kubectl points to '${context}', not ${CLUSTER_NAME}: run 'make kubeconfig'"
}

print_password() {
    local password
    password=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)
    [[ -n "${password}" ]] || die "admin secret not found (make kubeconfig, is ArgoCD installed?)"
    # Printed on the terminal only, never written to the log file.
    printf 'URL      : https://localhost:%s\nlogin    : admin\npassword : %s\n\nCtrl+C to close.\n' \
        "${PORT}" "${password}" >&2
}

main() {
    log_init "argocd-ui"
    check_context
    print_password
    kubectl -n argocd port-forward svc/argocd-server "${PORT}:443"
}

main "$@"
