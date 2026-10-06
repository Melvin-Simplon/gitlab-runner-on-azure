#!/usr/bin/env bash
# Runs every static check and reports all problems at once.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"

require_cmd terraform shellcheck

check_fmt() {
    task "terraform : fmt"
    if terraform fmt -check -recursive terraform >&2; then
        ok terraform "formatted"
    else
        failed terraform "run 'terraform fmt -recursive terraform'"
    fi
}

check_validate() {
    task "terraform : validate"
    local dir
    for dir in terraform/*/; do
        # Separate data dir, so the real .terraform/ is never touched.
        if TF_DATA_DIR="${PWD}/${dir}.terraform-lint" terraform -chdir="${dir}" init -backend=false -input=false >>"${LOG_FILE}" 2>&1 \
            && TF_DATA_DIR="${PWD}/${dir}.terraform-lint" terraform -chdir="${dir}" validate -no-color >&2; then
            ok "${dir}" "valid"
        else
            failed "${dir}" "invalid"
        fi
    done
}

check_tflint() {
    task "terraform : tflint"
    if ! command -v tflint >/dev/null; then
        skipped tflint "not installed"
        return
    fi
    if tflint --recursive --chdir=terraform >&2; then
        ok tflint "no issue"
    else
        failed tflint "see above"
    fi
}

check_shell() {
    task "scripts : shellcheck"
    if shellcheck -x scripts/*.sh >&2; then
        ok scripts "no issue"
    else
        failed scripts "see above"
    fi
}

main() {
    log_init "lint"
    recap_keys ok failed skipped
    check_fmt
    check_validate
    check_tflint
    check_shell
    recap lint
}

main "$@"
