#!/usr/bin/env bash
# Prints the make targets, grouped by '##@' section, from the Makefile and its includes.
set -euo pipefail

# Section colors and display order.
readonly SECTIONS=("Setup=36" "Infra=33" "Cluster=32" "Runner=34" "Grafana=33" "Dev=35")

main() {
    local -A lines=()
    local file section="" line target desc
    for file in "$@"; do
        while IFS= read -r line; do
            if [[ "${line}" =~ ^##@[[:space:]]*(.+)$ ]]; then
                section=${BASH_REMATCH[1]}
            elif [[ "${line}" =~ ^([a-zA-Z0-9_-]+):.*##[[:space:]]*(.+)$ ]]; then
                target=${BASH_REMATCH[1]}
                desc=${BASH_REMATCH[2]}
                lines[${section}]+=$(printf '  \e[1m%-18s\e[0m %s' "${target}" "${desc}")$'\n'
            fi
        done <"${file}"
    done
    printf 'Usage: make <target>\n'
    local entry name color
    for entry in "${SECTIONS[@]}"; do
        name=${entry%%=*}
        color=${entry#*=}
        [[ -n "${lines[${name}]:-}" ]] || continue
        printf '\n\e[%sm%s\e[0m\n%s' "${color}" "${name}" "${lines[${name}]}"
    done
}

main "$@"
