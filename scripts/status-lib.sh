#!/usr/bin/env bash
# Helpers shared by the status, alerts, backups and top scripts.

# Colors for the tables printed on stdout.
if [[ -t 1 && -t 2 && -z "${NO_COLOR:-}" ]]; then
    T_GREEN=$'\e[32m' T_YELLOW=$'\e[33m' T_RED=$'\e[1;31m'
    T_GREY=$'\e[90m' T_BOLD=$'\e[1m' T_PINK=$'\e[38;5;212m' T_RESET=$'\e[0m'
else
    T_GREEN='' T_YELLOW='' T_RED='' T_GREY='' T_BOLD='' T_PINK='' T_RESET=''
fi

readonly ALERTMANAGER_API="/api/v1/namespaces/monitoring/services/http:vmalert-victoria-metrics-alert-alertmanager:9093/proxy/api/v2/alerts"

# Prints a title line for a table.
title() {
    printf '\n%s%s %s %s\n' "${T_PINK}" "${T_BOLD}" "$1" "${T_RESET}"
}

# Prints the color of a percentage: green, then yellow from 70, then red from 85.
pct_color() {
    if (( $1 >= 85 )); then
        printf '%s' "${T_RED}"
    elif (( $1 >= 70 )); then
        printf '%s' "${T_YELLOW}"
    else
        printf '%s' "${T_GREEN}"
    fi
}

# Prints 20 blocks filled up to a percentage, in the given color.
blocks() {
    local pct=$1 color=$2 width=20 full
    (( pct > 100 )) && pct=100
    full=$(( pct * width / 100 ))
    printf '%s%s%s%s%s' "${color}" "$(printf '%*s' "${full}" '' | sed 's/ /█/g')" \
        "${T_GREY}" "$(printf '%*s' $(( width - full )) '' | sed 's/ /░/g')" "${T_RESET}"
}

# Prints a bar colored by how full it is, then the percentage.
bar() {
    printf '%s %3d%%' "$(blocks "$1" "$(pct_color "$1")")" "$1"
}

# Prints how long ago an ISO date was, like 3h12m.
ago() {
    local seconds
    seconds=$(( $(date +%s) - $(date -d "$1" +%s) ))
    if (( seconds >= 86400 )); then
        printf '%dd%02dh' $(( seconds / 86400 )) $(( seconds % 86400 / 3600 ))
    elif (( seconds >= 3600 )); then
        printf '%dh%02dm' $(( seconds / 3600 )) $(( seconds % 3600 / 60 ))
    else
        printf '%dm' $(( seconds / 60 ))
    fi
}

# Prints the firing alerts as JSON, read through the Kubernetes API.
alerts_json() {
    kubectl get --raw "${ALERTMANAGER_API}?silenced=false"
}

# Stops with a clear message when the cluster cannot be reached.
require_cluster() {
    require_cmd kubectl
    require_context
    kubectl get --raw /readyz >/dev/null 2>&1 \
        || die "the cluster does not answer, is it started? (make start)"
}
