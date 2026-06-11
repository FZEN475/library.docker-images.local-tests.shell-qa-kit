#!/usr/bin/env ash

export LC_ALL=C.UTF-8
export BATS_REPORT_FILENAME="bash-bats.xunit.xml"
export CI_PROJECT_DIR="$(pwd)"

source /ci/tbc/tbc-bash.sh

run_subprocess() {
    local script="$1"
    ash -c "source /tmp/current_env.sh; source $script"
}
export -p > /tmp/current_env.sh
install_ca_certs "$([[ -f "$CUSTOM_CA_FILE" ]] && cat "$CUSTOM_CA_FILE")"

log_info "---> bash-shellcheck <---"
if [ "$BASH_SHELLCHECK_ENABLED" = "true" ]; then
    run_subprocess /ci/build/shellcheck.sh
else
    log_info "Действие пропущено: BASH_SHELLCHECK_ENABLED='$BASH_SHELLCHECK_ENABLED'"
fi

log_info "---> bash-bats <---"
if [ "$BASH_BATS_ENABLED" = "true" ]; then
    run_subprocess /ci/build/bats.sh
else
    log_info "Действие пропущено: BASH_BATS_ENABLED='$BASH_BATS_ENABLED'"
fi

log_info "---> bash-coverage <---"
if [ "$BASH_COVERAGE_ENABLED" = "true" ]; then
    run_subprocess /ci/build/coverage.sh
else
    log_info "Действие пропущено: BASH_COVERAGE_ENABLED='$BASH_COVERAGE_ENABLED'"
fi
