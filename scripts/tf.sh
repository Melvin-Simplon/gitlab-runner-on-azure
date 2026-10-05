#!/usr/bin/env bash
# Runs one Terraform stack: tf.sh <infra|bootstrap> <plan|apply|destroy>
# apply and destroy always go through a saved plan, applied only after confirmation.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

require_env AZ_SUBSCRIPTION_ID AZ_RESOURCE_GROUP CLUSTER_NAME GITLAB_PROJECT_ID
require_cmd az terraform

[[ $# -eq 2 ]] || die "usage: tf.sh <infra|bootstrap> <plan|apply|destroy>"
readonly STACK=$1 ACTION=$2
readonly DIR="terraform/${STACK}"
readonly PLAN_FILE="tfplan"
[[ -d "${DIR}" ]] || die "unknown stack: ${STACK}"
[[ "${ACTION}" =~ ^(plan|apply|destroy)$ ]] || die "unknown action: ${ACTION}"

# The bootstrap stack talks to the Kubernetes API: the cluster must exist and run.
# Returns 1 when there is nothing to do.
check_cluster() {
    [[ "${STACK}" == "bootstrap" ]] || return 0
    local state
    state=$(cluster_state)
    case "${state}" in
        Running) return 0 ;;
        Stopped) die "cluster ${CLUSTER_NAME} is stopped, run 'make start' first" ;;
        absent)
            [[ "${ACTION}" == "apply" ]] && die "cluster ${CLUSTER_NAME} does not exist, apply the infra stack first"
            skipped "${STACK}" "no cluster, nothing to do"
            return 1 ;;
        *) die "cluster ${CLUSTER_NAME} is in a transient state (${state}), retry later" ;;
    esac
}

# GitLab-managed state over the http backend. Credentials go through TF_HTTP_* variables
# so they are never persisted in .terraform/.
set_backend_env() {
    local address="https://gitlab.com/api/v4/projects/${GITLAB_PROJECT_ID}/terraform/state/${STACK}"
    export TF_HTTP_ADDRESS="${address}"
    export TF_HTTP_LOCK_ADDRESS="${address}/lock" TF_HTTP_LOCK_METHOD=POST
    export TF_HTTP_UNLOCK_ADDRESS="${address}/lock" TF_HTTP_UNLOCK_METHOD=DELETE
    export TF_HTTP_RETRY_WAIT_MIN=5
    require_env GITLAB_USER GITLAB_TOKEN
    export TF_HTTP_USERNAME="${GITLAB_USER}" TF_HTTP_PASSWORD="${GITLAB_TOKEN}"
}

tf_init() {
    task "${STACK} : init"
    local mode=(-reconfigure)
    # One-off: a working copy still bound to the former Azure Storage backend copies its state to GitLab.
    if grep -q '"type": "azurerm"' "${DIR}/.terraform/terraform.tfstate" 2>/dev/null; then
        mode=(-migrate-state -force-copy)
        info "migrating the ${STACK} state from Azure Storage to GitLab"
    fi
    if terraform -chdir="${DIR}" init -input=false -no-color "${mode[@]}" >>"${LOG_FILE}" 2>&1; then
        ok "${STACK}" "GitLab state: project ${GITLAB_PROJECT_ID}, ${STACK}"
    else
        die "terraform init failed, details in ${LOG_FILE}"
    fi
}

# tf_plan: returns 0 when no change, 2 when changes are planned.
tf_plan() {
    task "${STACK} : plan"
    local args=(-input=false -out="${PLAN_FILE}" -detailed-exitcode)
    [[ "${ACTION}" == "destroy" ]] && args+=(-destroy)
    local rc=0
    terraform -chdir="${DIR}" plan "${args[@]}" || rc=$?
    terraform -chdir="${DIR}" show -no-color "${PLAN_FILE}" >>"${LOG_FILE}" 2>&1 || true
    case "${rc}" in
        0) ok "${STACK}" "no change" ;;
        2) changed "${STACK}" "changes planned" ;;
        *) die "terraform plan failed" ;;
    esac
    return "${rc}"
}

tf_apply() {
    task "${STACK} : ${ACTION}"
    confirm "Apply this plan to ${STACK}?" || die "cancelled by the operator"
    # Plain pipe, no process substitution: tee finishes before the script exits, the error lands in the log.
    terraform -chdir="${DIR}" apply -input=false -no-color "${PLAN_FILE}" 2>&1 | tee -a "${LOG_FILE}" \
        || die "terraform apply failed, details in ${LOG_FILE}"
    changed "${STACK}" "plan applied"
}

main() {
    log_init "tf ${STACK} ${ACTION}"
    recap_keys ok changed skipped
    trap 'rm -f "${DIR}/${PLAN_FILE}"' EXIT
    set_backend_env
    if check_cluster; then
        tf_init
        local rc=0
        tf_plan || rc=$?
        if [[ "${rc}" -eq 2 && "${ACTION}" != "plan" ]]; then
            tf_apply
        fi
    fi
    recap "${STACK}"
}

main "$@"
