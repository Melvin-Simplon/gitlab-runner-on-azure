#!/usr/bin/env bash
# Creates the Grafana admin password once, or shows it.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

require_env CLUSTER_NAME
require_cmd kubectl openssl
readonly NAMESPACE="monitoring"
readonly SECRET="grafana-admin"

[[ $# -eq 1 ]] || die "usage: grafana-secret.sh <create|show>"
readonly ACTION=$1

ensure_secret() {
    task "grafana : admin secret"
    if kubectl -n "${NAMESPACE}" get secret "${SECRET}" -o name >/dev/null 2>&1; then
        ok "${SECRET}" "already exists, password kept"
        return
    fi
    local password manifest
    password=$(openssl rand -base64 24)
    manifest=$(kubectl -n "${NAMESPACE}" create secret generic "${SECRET}" \
        --from-literal=admin-user=admin \
        --from-literal=admin-password="${password}" \
        --dry-run=client -o yaml)
    apply_manifest "${SECRET}" "${manifest}"
}

# Printed on the terminal only, never written to the log file.
show_password() {
    local password
    password=$(kubectl -n "${NAMESPACE}" get secret "${SECRET}" \
        -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || true)
    [[ -n "${password}" ]] || die "secret ${SECRET} not found, run 'make grafana-secret'"
    printf 'URL      : https://gitlab-runner-mpetit.francecentral.cloudapp.azure.com\nlogin    : admin\npassword : %s\n' \
        "${password}" >&2
}

main() {
    log_init "grafana-secret ${ACTION}"
    require_context
    case "${ACTION}" in
        create)
            recap_keys ok changed
            task "grafana : namespace"
            ensure_namespace "${NAMESPACE}"
            ensure_secret
            recap grafana ;;
        show) show_password ;;
        *) die "unknown action: ${ACTION}" ;;
    esac
}

main "$@"
