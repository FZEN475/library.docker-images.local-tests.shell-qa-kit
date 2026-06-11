source /ci/tbc/tbc-bash.sh
mkdir -p -m 777 reports

set -a
source /tmp/current_env.sh >/dev/null 2>&1
set +a

echo "call: shellcheck $BASH_SHELLCHECK_OPTS $(glob_expand $BASH_SHELLCHECK_FILES)"
shellcheck $BASH_SHELLCHECK_OPTS $(glob_expand $BASH_SHELLCHECK_FILES)