#!/usr/bin/env bash
# Lists the alerts that fire now, the hidden ones in grey.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
# shellcheck source=scripts/status-lib.sh
source "$(dirname "$0")/status-lib.sh"

require_cmd jq

# Prints one tab separated line per alert: severity, state, start, name, summary.
alert_lines() {
    alerts_json | jq -r 'sort_by(.labels.severity, .labels.alertname)[]
        | [.labels.severity, .status.state, .startsAt, .labels.alertname, .annotations.summary] | @tsv'
}

print_alert() {
    local severity=$1 state=$2 since=$3 name=$4 summary=$5 color
    case "${severity}" in
        critical) color=${T_RED} ;;
        warning)  color=${T_YELLOW} ;;
        *)        color=${T_GREY} ;;
    esac
    if [[ "${state}" == "suppressed" ]]; then
        color=${T_GREY}
        severity="hidden"
    fi
    printf '  %s%-9s%s %-26s %s%6s%s  %s\n' "${color}${T_BOLD}" "${severity}" "${T_RESET}" \
        "${name}" "${T_GREY}" "$(ago "${since}")" "${T_RESET}" "${summary}"
}

main() {
    require_cluster
    local lines severity state since name summary
    lines=$(alert_lines)
    title "Firing alerts"
    if [[ -z "${lines}" ]]; then
        printf '  %sNothing fires, all good.%s\n' "${T_GREEN}" "${T_RESET}"
        return 0
    fi
    while IFS=$'\t' read -r severity state since name summary; do
        print_alert "${severity}" "${state}" "${since}" "${name}" "${summary}"
    done <<<"${lines}"
    printf '\n  %sHidden alerts are explained by another alert that fires.%s\n' "${T_GREY}" "${T_RESET}"
}

main "$@"
