#!/usr/bin/env bash
# Checks the whole platform in one pass and never stops at the first problem.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
# shellcheck source=scripts/status-lib.sh
source "$(dirname "$0")/status-lib.sh"

require_env AZ_SUBSCRIPTION_ID AZ_RESOURCE_GROUP CLUSTER_NAME DOMAIN
require_cmd az kubectl jq curl

healthy() { _issue healthy "${C_GREEN}"  ok       "$1" "${2:-}"; }
warning() { _issue warning "${C_YELLOW}" warning  "$1" "${2:-}"; }
broken()  { _issue broken  "${C_RED}"    fatal    "$1" "${2:-}"; }

check_cluster() {
    task "azure : cluster power"
    local state
    state=$(cluster_state)
    if [[ "${state}" == "Running" ]]; then
        healthy "${CLUSTER_NAME}" "running"
    else
        broken "${CLUSTER_NAME}" "${state}, run 'make start' or 'make up'"
        return 1
    fi
}

check_nodes() {
    task "kubernetes : nodes"
    local name ready cpu mem
    while read -r name ready; do
        if [[ "${ready}" == "True" ]]; then
            healthy "${name}" "ready"
        else
            broken "${name}" "not ready"
        fi
    done < <(kubectl get nodes --no-headers \
        -o custom-columns='N:.metadata.name,R:.status.conditions[?(@.type=="Ready")].status')
    while read -r name _ cpu _ mem; do
        info "    ${name}  cpu $(bar "${cpu%\%}")   memory $(bar "${mem%\%}")"
    done < <(kubectl top nodes --no-headers 2>/dev/null)
}

check_apps() {
    task "argocd : applications"
    local name sync health
    while read -r name sync health; do
        if [[ "${sync}" == "Synced" && "${health}" == "Healthy" ]]; then
            healthy "${name}" "synced, healthy"
        elif [[ "${health}" == "Degraded" || "${health}" == "Missing" ]]; then
            broken "${name}" "${sync}, ${health}"
        else
            warning "${name}" "${sync}, ${health}"
        fi
    done < <(kubectl get applications -n argocd --no-headers \
        -o custom-columns='N:.metadata.name,S:.status.sync.status,H:.status.health.status')
}

check_pods() {
    task "kubernetes : pods"
    local ns name ready status bad=0
    while read -r ns name ready status _; do
        [[ "${status}" == "Completed" ]] && continue
        if [[ "${status}" != "Running" || "${ready%/*}" != "${ready#*/}" ]]; then
            broken "${ns}/${name}" "${status} ${ready}"
            bad=$((bad + 1))
        fi
    done < <(kubectl get pods -A --no-headers)
    (( bad == 0 )) && healthy "pods" "$(kubectl get pods -A --no-headers | wc -l) pods running"
    return 0
}

check_alerts() {
    task "vmalert : firing alerts"
    local json critical warn
    if ! json=$(alerts_json 2>/dev/null); then
        unreachable "alertmanager" "no answer"
        return 0
    fi
    critical=$(jq '[.[] | select(.status.state == "active" and .labels.severity == "critical")] | length' <<<"${json}")
    warn=$(jq '[.[] | select(.status.state == "active" and .labels.severity == "warning")] | length' <<<"${json}")
    if (( critical > 0 )); then
        broken "alerts" "${critical} critical, ${warn} warning, see 'make alerts'"
    elif (( warn > 0 )); then
        warning "alerts" "${warn} warning, see 'make alerts'"
    else
        healthy "alerts" "none firing"
    fi
}

check_backups() {
    task "velero : last scheduled backup"
    local line name phase done_at
    line=$(kubectl get backups.velero.io -n velero -l velero.io/schedule-name --sort-by=.metadata.creationTimestamp \
        --no-headers -o custom-columns='N:.metadata.name,P:.status.phase,D:.status.completionTimestamp' | tail -1)
    if [[ -z "${line}" ]]; then
        warning "velero" "no scheduled backup yet"
        return 0
    fi
    read -r name phase done_at <<<"${line}"
    if [[ "${phase}" != "Completed" ]]; then
        broken "${name}" "${phase}"
    elif (( $(date +%s) - $(date -d "${done_at}" +%s) > 7 * 3600 )); then
        warning "${name}" "completed $(ago "${done_at}") ago, older than 7h"
    else
        healthy "${name}" "completed $(ago "${done_at}") ago"
    fi
}

check_grafana() {
    task "grafana : https"
    local ready not_after code
    read -r ready not_after < <(kubectl get certificate grafana-tls -n monitoring --no-headers \
        -o custom-columns='R:.status.conditions[?(@.type=="Ready")].status,A:.status.notAfter')
    if [[ "${ready}" == "True" ]]; then
        healthy "certificate" "valid for $(( ($(date -d "${not_after}" +%s) - $(date +%s)) / 86400 )) days"
    else
        broken "certificate" "not ready"
    fi
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://${DOMAIN}/api/health" || true)
    if [[ "${code}" == "200" ]]; then
        healthy "https://${DOMAIN}" "answers 200"
    else
        unreachable "https://${DOMAIN}" "answers ${code:-nothing}"
    fi
}

check_runner() {
    task "gitlab : runner"
    local ready
    ready=$(kubectl get deploy gitlab-runner -n gitlab-runner -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
    if (( ${ready:-0} > 0 )); then
        healthy "gitlab-runner" "${ready} pod ready"
    else
        broken "gitlab-runner" "no pod ready"
    fi
}

main() {
    log_init "status"
    recap_keys healthy warning broken unreachable skipped
    if check_cluster; then
        require_cluster
        check_nodes
        check_apps
        check_pods
        check_alerts
        check_backups
        check_grafana
        check_runner
    else
        skipped "kubernetes" "cluster not running"
    fi
    recap status || true
    (( RECAP[broken] == 0 && RECAP[unreachable] == 0 ))
}

main "$@"
