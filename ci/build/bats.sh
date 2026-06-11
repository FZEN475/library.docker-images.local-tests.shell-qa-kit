source /ci/tbc/tbc-bash.sh
mkdir -p -m 777 reports

set -a
source /tmp/current_env.sh >/dev/null 2>&1
set +a

install_bats_libs
echo "call: bats --report-formatter junit --output reports $BASH_BATS_OPTS $BASH_BATS_TESTS"
bats --report-formatter junit --output reports $BASH_BATS_OPTS $BASH_BATS_TESTS