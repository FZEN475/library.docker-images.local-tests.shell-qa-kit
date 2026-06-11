source /ci/tbc/tbc-bash.sh
mkdir -p -m 777 reports

set -a
source /tmp/current_env.sh >/dev/null 2>&1
set +a

install_bashcov
# prevent shell expension of string values
set -f
config_simplecov "${CI_PROJECT_DIR}" ".git/, ${BASH_BATS_TESTS}/, ${BASH_COVERAGE_FILTERS}" "${BASH_COVERAGE_FORMATTERS}"
set +f

log_info "$(cat ./.simplecov)"


set -- --report-formatter junit --output reports $BASH_BATS_OPTS $BASH_BATS_TESTS
echo "call: bashcov -- bats \"$*\" "
bashcov -- bats "$@" || exit_code=$?

# shellcheck disable=SC2086
echo "exit_code=$exit_code"