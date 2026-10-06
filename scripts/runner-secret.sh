#!/usr/bin/env bash
# Creates or updates the Secret holding the runner authentication token (glrt-...). Idempotent.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

require_env CLUSTER_NAME
require_cmd kubectl
readonly NAMESPACE="gitlab-runner"
readonly SECRET="gitlab-runner-token"

ensure_secret() {
    task "runner : token secret"
    # runner-registration-token must exist and stay empty with an authentication token.
    local manifest
    manifest=$(kubectl -n "${NAMESPACE}" create secret generic "${SECRET}" \
        --from-literal=runner-registration-token="" \
        --from-literal=runner-token="${GITLAB_RUNNER_TOKEN}" \
        --dry-run=client -o yaml)
    apply_manifest "${SECRET}" "${manifest}"
}

main() {
    log_init "runner-secret"
    recap_keys ok changed skipped
    if [[ -z "${GITLAB_RUNNER_TOKEN:-}" ]]; then
        task "runner : token secret"
        skipped "${SECRET}" "GITLAB_RUNNER_TOKEN not set, secret left as is"
    elif [[ "${GITLAB_RUNNER_TOKEN}" != glrt-* ]]; then
        die "GITLAB_RUNNER_TOKEN must be a runner authentication token (glrt-...)"
    else
        require_context
        task "runner : namespace"
        ensure_namespace "${NAMESPACE}"
        ensure_secret
    fi
    recap runner
}

main "$@"
