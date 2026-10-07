#!/usr/bin/env bash
# Lists the Velero backups, newest first, colored by result.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
# shellcheck source=scripts/status-lib.sh
source "$(dirname "$0")/status-lib.sh"

print_backup() {
    local name=$1 phase=$2 done_at=$3 expires=$4 items=$5 color age="-" left="-"
    case "${phase}" in
        Completed)                 color=${T_GREEN} ;;
        InProgress|New)            color=${T_YELLOW} ;;
        *)                         color=${T_RED} ;;
    esac
    [[ "${done_at}" != "<none>" ]] && age="$(ago "${done_at}") ago"
    [[ "${expires}" != "<none>" ]] && left="$(( ($(date -d "${expires}" +%s) - $(date +%s)) / 3600 ))h"
    printf '  %s●%s %-34s %s%-16s%s %-12s %s%5s items, expires in %s%s\n' "${color}" "${T_RESET}" \
        "${name}" "${color}" "${phase}" "${T_RESET}" "${age}" "${T_GREY}" "${items}" "${left}" "${T_RESET}"
}

main() {
    require_cluster
    local lines name phase done_at expires items
    lines=$(kubectl get backups.velero.io -n velero --sort-by=.metadata.creationTimestamp --no-headers \
        -o custom-columns='N:.metadata.name,P:.status.phase,D:.status.completionTimestamp,E:.status.expiration,I:.status.progress.itemsBackedUp')
    title "Velero backups"
    if [[ -z "${lines}" ]]; then
        printf '  %sNo backup yet.%s\n' "${T_YELLOW}" "${T_RESET}"
        return 0
    fi
    while read -r name phase done_at expires items; do
        print_backup "${name}" "${phase}" "${done_at}" "${expires}" "${items}"
    done < <(tac <<<"${lines}")
    printf '\n  %sA scheduled backup runs every 6 hours and is kept 7 days.%s\n' "${T_GREY}" "${T_RESET}"
}

main "$@"
