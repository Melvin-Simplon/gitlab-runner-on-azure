#!/usr/bin/env bash
# Shared helpers, sourced by every script: Ansible-style output, log file, guards.
# Diagnostics go to stderr, stdout stays free for return values.

: "${LOG_FILE:=.logs/pipeline.log}"

if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
    C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' C_CYAN=$'\e[36m' C_RED=$'\e[31m' C_BRED=$'\e[1;31m' C_RESET=$'\e[0m'
else
    C_GREEN='' C_YELLOW='' C_CYAN='' C_RED='' C_BRED='' C_RESET=''
fi

declare -A RECAP=()
RECAP_KEYS=()

# recap_keys ok changed skipped failed: declares the counters shown in PLAY RECAP, in order.
recap_keys() {
    RECAP_KEYS=("$@")
    local k
    for k in "$@"; do RECAP[$k]=0; done
}

log_init() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    touch "${LOG_FILE}"
    chmod 600 "${LOG_FILE}"
    printf '\n===== %s %s =====\n' "$(date -Is)" "$*" >>"${LOG_FILE}"
}

_to_log() {
    printf '%s %s\n' "$(date -Is)" "$*" >>"${LOG_FILE}"
}

task() {
    local head="TASK [$1] "
    local stars
    stars=$(printf '%*s' $((72 - ${#head})) '' | tr ' ' '*')
    printf '\n%s%s\n' "${head}" "${stars}" >&2
    _to_log "TASK [$1]"
}

# _issue <counter> <color> <label> <target> <message>
# Called directly (never inside $(...)) so the counter update survives.
_issue() {
    local counter=$1 color=$2 label=$3 target=$4 msg=$5
    RECAP[$counter]=$((${RECAP[$counter]:-0} + 1))
    printf '%s%-12s [%s] %s%s\n' "${color}" "${label}:" "${target}" "${msg}" "${C_RESET}" >&2
    _to_log "${label}: [${target}] ${msg}"
}

ok()          { _issue ok          "${C_GREEN}"  ok          "$1" "${2:-}"; }
changed()     { _issue changed     "${C_YELLOW}" changed     "$1" "${2:-}"; }
skipped()     { _issue skipped     "${C_CYAN}"   skipping    "$1" "${2:-}"; }
failed()      { _issue failed      "${C_RED}"    fatal       "$1" "${2:-}"; }
unreachable() { _issue unreachable "${C_BRED}"   unreachable "$1" "${2:-}"; }

info() {
    printf '%s\n' "$*" >&2
    _to_log "$*"
}

die() {
    printf '%sfatal: %s%s\n' "${C_RED}" "$*" "${C_RESET}" >&2
    _to_log "fatal: $*"
    exit 1
}

require_env() {
    local v
    for v in "$@"; do
        [[ -n "${!v:-}" ]] || die "variable ${v} is missing (see .env.example)"
    done
}

require_cmd() {
    local c
    for c in "$@"; do
        command -v "${c}" >/dev/null || die "command '${c}' not found"
    done
}

require_context() {
    local context
    context=$(kubectl config current-context 2>/dev/null || true)
    [[ "${context}" == "${CLUSTER_NAME}" ]] \
        || die "kubectl points to '${context}', not ${CLUSTER_NAME}: run 'make kubeconfig'"
}

# confirm <question>: yes without asking when CONFIRM=yes or stdin is not a terminal (CI).
confirm() {
    [[ "${CONFIRM:-}" == "yes" || ! -t 0 ]] && return 0
    local answer
    read -r -p "$1 [y/N] " answer
    [[ "${answer}" == [yY] ]]
}

# azs: az scoped to the project subscription (az ad commands do not take --subscription).
azs() {
    az "$@" --subscription "${AZ_SUBSCRIPTION_ID}"
}

# cluster_state: prints Running, Stopped or absent. Output is captured, logs go to stderr.
cluster_state() {
    azs aks show -g "${AZ_RESOURCE_GROUP}" -n "${CLUSTER_NAME}" \
        --query powerState.code -o tsv 2>/dev/null || printf 'absent'
}

# recap <host>: prints PLAY RECAP, returns non-zero if anything failed or was unreachable.
recap() {
    local line="" k
    for k in "${RECAP_KEYS[@]}"; do line+="${k}=${RECAP[$k]}  "; done
    printf '\nPLAY RECAP %s\n%-12s: %s\n' "$(printf '%*s' 61 '' | tr ' ' '*')" "$1" "${line}" >&2
    _to_log "PLAY RECAP $1 : ${line}"
    (( ${RECAP[failed]:-0} == 0 && ${RECAP[unreachable]:-0} == 0 ))
}
