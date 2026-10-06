#!/usr/bin/env bash
# Shared helpers sourced by every script.

: "${LOG_FILE:=.logs/pipeline.log}"

if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
    C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' C_CYAN=$'\e[36m' C_RED=$'\e[31m' C_BRED=$'\e[1;31m' C_RESET=$'\e[0m'
else
    C_GREEN='' C_YELLOW='' C_CYAN='' C_RED='' C_BRED='' C_RESET=''
fi

declare -A RECAP=()
RECAP_KEYS=()

# Sets the counters shown in PLAY RECAP, in order.
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

# Prints one result line and updates its counter, never call it inside $(...).
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

# Applies a manifest and reports ok when kubectl says unchanged.
apply_manifest() {
    local label=$1 manifest=$2 out
    out=$(kubectl apply -f - <<<"${manifest}" 2>&1) || die "kubectl apply failed: ${out}"
    if [[ "${out}" == *unchanged* ]]; then
        ok "${label}" "unchanged"
    else
        changed "${label}" "${out##* }"
    fi
}

ensure_namespace() {
    local manifest
    manifest=$(kubectl create namespace "$1" --dry-run=client -o yaml)
    apply_manifest "$1" "${manifest}"
}

# Asks yes or no, unless CONFIRM=yes or there is no terminal.
confirm() {
    [[ "${CONFIRM:-}" == "yes" || ! -t 0 ]] && return 0
    local answer
    read -r -p "$1 [y/N] " answer
    [[ "${answer}" == [yY] ]]
}

# Runs az on the project subscription.
azs() {
    az "$@" --subscription "${AZ_SUBSCRIPTION_ID}"
}

# Prints Running, Stopped or absent.
cluster_state() {
    azs aks show -g "${AZ_RESOURCE_GROUP}" -n "${CLUSTER_NAME}" \
        --query powerState.code -o tsv 2>/dev/null || printf 'absent'
}

# Prints PLAY RECAP and fails if anything failed.
recap() {
    local line="" k
    for k in "${RECAP_KEYS[@]}"; do line+="${k}=${RECAP[$k]}  "; done
    printf '\nPLAY RECAP %s\n%-12s: %s\n' "$(printf '%*s' 61 '' | tr ' ' '*')" "$1" "${line}" >&2
    _to_log "PLAY RECAP $1 : ${line}"
    (( ${RECAP[failed]:-0} == 0 && ${RECAP[unreachable]:-0} == 0 ))
}
