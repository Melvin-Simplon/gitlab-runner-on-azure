#!/usr/bin/env bash
# Shows the CPU and memory used by each node and by the hungriest pods.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
# shellcheck source=scripts/status-lib.sh
source "$(dirname "$0")/status-lib.sh"

readonly TOP_PODS=10

print_nodes() {
    local name cpu mem
    title "Nodes"
    while read -r name _ cpu _ mem; do
        printf '  %-32s cpu %s   memory %s\n' "${name}" "$(bar "${cpu%\%}")" "$(bar "${mem%\%}")"
    done < <(kubectl top nodes --no-headers)
}

# Pod bars compare the pods to the hungriest one, so they stay pink.
print_pods() {
    local lines max ns name cpu mem
    title "Top ${TOP_PODS} pods by memory"
    lines=$(kubectl top pods -A --no-headers --sort-by=memory)
    lines=$(head -n "${TOP_PODS}" <<<"${lines}")
    max=$(awk 'NR == 1 { print $4 + 0 }' <<<"${lines}")
    while read -r ns name cpu mem; do
        printf '  %-14s %-46s %s %7s %s%6s%s\n' "${ns}" "${name:0:46}" \
            "$(blocks $(( ${mem%Mi} * 100 / max )) "${T_PINK}")" "${mem}" "${T_GREY}" "${cpu}" "${T_RESET}"
    done <<<"${lines}"
}

main() {
    require_cluster
    print_nodes
    print_pods
}

main "$@"
