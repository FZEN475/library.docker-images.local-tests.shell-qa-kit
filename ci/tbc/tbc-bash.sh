# BEGSCRIPT
set -eo pipefail

function log_info() {
    >&2 echo -e "[\\e[1;94mINFO\\e[0m] $*"
}

function log_warn() {
    >&2 echo -e "[\\e[1;93mWARN\\e[0m] $*"
}

function log_error() {
    >&2 echo -e "[\\e[1;91mERROR\\e[0m] $*"
}

function as_content() {
  file_or_content=$1
  if [[ -f "${file_or_content}" ]]; then
    cat "${file_or_content}"
  else
    echo "${file_or_content}"
  fi
}

function install_ca_certs() {
  certs=$1
  if [[ -z "$certs" ]]
  then
    return
  fi

  # import in system
  if as_content "$certs" >> /etc/ssl/certs/ca-certificates.crt
  then
    log_info "CA certificates imported in \\e[33;1m/etc/ssl/certs/ca-certificates.crt\\e[0m"
  fi
  if as_content "$certs" >> /etc/ssl/cert.pem
  then
    log_info "CA certificates imported in \\e[33;1m/etc/ssl/cert.pem\\e[0m"
  fi
}

function unscope_variables() {
  _scoped_vars=$(env | awk -F '=' "/^scoped__[a-zA-Z0-9_]+=/ {print \$1}" | sort)
  if [[ -z "$_scoped_vars" ]]; then return; fi
  log_info "Processing scoped variables..."
  for _scoped_var in $_scoped_vars
  do
    _fields=${_scoped_var//__/:}
    _condition=$(echo "$_fields" | cut -d: -f3)
    case "$_condition" in
    if) _not="";;
    ifnot) _not=1;;
    *)
      log_warn "... unrecognized condition \\e[1;91m$_condition\\e[0m in \\e[33;1m${_scoped_var}\\e[0m"
      continue
    ;;
    esac
    _target_var=$(echo "$_fields" | cut -d: -f2)
    _cond_var=$(echo "$_fields" | cut -d: -f4)
    _cond_val=$(eval echo "\$${_cond_var}")
    _test_op=$(echo "$_fields" | cut -d: -f5)
    case "$_test_op" in
    defined)
      if [[ -z "$_not" ]] && [[ -z "$_cond_val" ]]; then continue;
      elif [[ "$_not" ]] && [[ "$_cond_val" ]]; then continue;
      fi
      ;;
    equals|startswith|endswith|contains|in|equals_ic|startswith_ic|endswith_ic|contains_ic|in_ic)
      # comparison operator
      # sluggify actual value
      _cond_val=$(echo "$_cond_val" | tr '[:punct:]' '_')
      # retrieve comparison value
      _cmp_val_prefix="scoped__${_target_var}__${_condition}__${_cond_var}__${_test_op}__"
      _cmp_val=${_scoped_var#"$_cmp_val_prefix"}
      # manage 'ignore case'
      if [[ "$_test_op" =~ _ic$ ]]
      then
        # lowercase everything
        _cond_val=$(echo "$_cond_val" | tr '[:upper:]' '[:lower:]')
        _cmp_val=$(echo "$_cmp_val" | tr '[:upper:]' '[:lower:]')
      fi
      case "$_test_op" in
      equals*)
        if [[ -z "$_not" ]] && [[ "$_cond_val" != "$_cmp_val" ]]; then continue;
        elif [[ "$_not" ]] && [[ "$_cond_val" == "$_cmp_val" ]]; then continue;
        fi
        ;;
      startswith*)
        if [[ -z "$_not" ]] && [[ ! "$_cond_val" =~ ^"$_cmp_val" ]]; then continue;
        elif [[ "$_not" ]] && [[ "$_cond_val" =~ ^"$_cmp_val" ]]; then continue;
        fi
        ;;
      endswith*)
        if [[ -z "$_not" ]] && [[ ! "$_cond_val" =~ "$_cmp_val"$ ]]; then continue;
        elif [[ "$_not" ]] && [[ "$_cond_val" =~ "$_cmp_val"$ ]]; then continue;
        fi
        ;;
      contains*)
        # shellcheck disable=SC2076
        if [[ -z "$_not" ]] && [[ ! "$_cond_val" =~ "$_cmp_val" ]]; then continue;
        elif [[ "$_not" ]] && [[ "$_cond_val" =~ "$_cmp_val" ]]; then continue;
        fi
        ;;
      in*)
        if [[ -z "$_not" ]] && [[ ! __"$_cmp_val"__ =~ __"$_cond_val"__ ]]; then continue;
        elif [[ "$_not" ]] && [[ __"$_cmp_val"__ =~ __"$_cond_val"__ ]]; then continue;
        fi
        ;;
      esac
      ;;
    *)
      log_warn "... unrecognized test operator \\e[1;91m${_test_op}\\e[0m in \\e[33;1m${_scoped_var}\\e[0m"
      continue
      ;;
    esac
    # matches
    _val=$(eval echo "\$${_target_var}")
    log_info "... apply \\e[32m${_target_var}\\e[0m from \\e[32m\$${_scoped_var}\\e[0m${_val:+ }"
    _val=$(eval echo "\$${_scoped_var}")
    export "${_target_var}"="${_val}"
  done
  log_info "... done"
}

# evaluate and export a secret
# - $1: secret variable name
function eval_secret() {
  name=$1
  value=$(eval echo "\$${name}")
  case "$value" in
  @b64@*)
    decoded=$(mktemp)
    errors=$(mktemp)
    if echo "$value" | cut -c6- | base64 -d > "${decoded}" 2> "${errors}"
    then
      # shellcheck disable=SC2086
      export ${name}="$(cat ${decoded})"
      log_info "Successfully decoded base64 secret \\e[33;1m${name}\\e[0m"
    else
      fail "Failed decoding base64 secret \\e[33;1m${name}\\e[0m:\\n$(sed 's/^/... /g' "${errors}")"
    fi
    ;;
  @hex@*)
    decoded=$(mktemp)
    errors=$(mktemp)
    if echo "$value" | cut -c6- | sed 's/\([0-9A-F]\{2\}\)/\\\\x\1/gI' | xargs printf > "${decoded}" 2> "${errors}"
    then
      # shellcheck disable=SC2086
      export ${name}="$(cat ${decoded})"
      log_info "Successfully decoded hexadecimal secret \\e[33;1m${name}\\e[0m"
    else
      fail "Failed decoding hexadecimal secret \\e[33;1m${name}\\e[0m:\\n$(sed 's/^/... /g' "${errors}")"
    fi
    ;;
  @url@*)
    url=$(echo "$value" | cut -c6-)
    if command -v curl > /dev/null
    then
      decoded=$(mktemp)
      errors=$(mktemp)
      if curl -s -S -f --connect-timeout "${TBC_SECRET_URL_TIMEOUT:-5}" -o "${decoded}" "$url" 2> "${errors}"
      then
        # shellcheck disable=SC2086
        export ${name}="$(cat ${decoded})"
        log_info "Successfully curl'd secret \\e[33;1m${name}\\e[0m"
      else
        log_warn "Failed getting secret \\e[33;1m${name}\\e[0m:\\n$(sed 's/^/... /g' "${errors}")"
      fi
    elif command -v wget > /dev/null
    then
      decoded=$(mktemp)
      errors=$(mktemp)
      if wget -T "${TBC_SECRET_URL_TIMEOUT:-5}" -O "${decoded}" "$url" 2> "${errors}"
      then
        # shellcheck disable=SC2086
        export ${name}="$(cat ${decoded})"
        log_info "Successfully wget'd secret \\e[33;1m${name}\\e[0m"
      else
        log_warn "Failed getting secret \\e[33;1m${name}\\e[0m:\\n$(sed 's/^/... /g' "${errors}")"
      fi
    else
      log_warn "Couldn't get secret \\e[33;1m${name}\\e[0m: no http client found"
    fi
    ;;
  esac
}

function eval_all_secrets() {
  # exclude scoped variables and their copies passed to container services (`<service_name>_ENV_scoped__xxx`)
  encoded_vars=$(env | awk -F '=' '$1 !~ /(^|_ENV_)scoped__/ && $2 ~ /^@(b64|hex|url)@/ {print $1}')
  for var in $encoded_vars
  do
    eval_secret "$var"
  done
}

function maybe_install_packages() {
  if command -v apt-get > /dev/null
  then
    # Debian
    if ! dpkg --status "$@" > /dev/null
    then
      apt-get update
      apt-get install --no-install-recommends --yes --quiet "$@"
    fi
  elif command -v apk > /dev/null
  then
    # Alpine
    if ! apk info --installed "$@" > /dev/null
    then
      apk add --no-cache "$@"
    fi
  else
    log_error "... didn't find any supported package manager to install $*"
    exit 1
  fi
}

function install_bats_libs() {
  export BATS_LIBRARIES_DIR=/opt/bats/libexec

  if [[ -z "$BASH_BATS_LIBRARIES" ]]
  then
    return
  fi

  if [[ "$https_proxy" || "$HTTPS_PROXY" ]]
  then
    # BusyBox wget doesn't support proxies and TLS/SSL at the same time: need to use offical full-featured wget instead

    maybe_install_packages wget
  fi

  # install Bats libraries
  for lib in $BASH_BATS_LIBRARIES
  do
    lib_name=$(echo "$lib" | cut -d@ -f 1)
    lib_url=$(echo "$lib" | cut -d@ -f 2)

    log_info "--- installing library \\e[32m${lib_name}\\e[0m from \\e[33;1m${lib_url}\\e[0m..."

    target=$(mktemp)

    # 1: download
    log_info " ... download with wget"
    wget -O "$target" "$lib_url"

    # 2: unzip
    log_info " ... unzip"
    unzip -d "$BATS_LIBRARIES_DIR" "$target"

    # 3: create symlink
    lib_dir=$(ls -d -1 "$BATS_LIBRARIES_DIR/${lib_name}"-* || echo "")
    if [[ "$lib_dir" ]]
    then
      log_info " ... create symbolic link \\e[32m${lib_name}\\e[0m -> \\e[33;1m$(basename "$lib_dir")\\e[0m..."
      ln -s "$lib_dir" "$BATS_LIBRARIES_DIR/$lib_name"
    fi
  done

  if [ -n "${TRACE}" ]; then
    # debug log
    log_info " ... DONE"
    ls -lart "$BATS_LIBRARIES_DIR"
  fi
}

function install_bashcov() {
  if ! command -v bashcov > /dev/null
  then
    log_info Installing ruby, simplecov, and bashcov
    maybe_install_packages ruby
    gem install simplecov simplecov-cobertura bashcov
    for package in $(simplecov_package_list)
    do
      if [[ -n "$package" ]]; then
        log_info "Installing additional library: ${package}"
        gem install "${package}"
      fi
    done
  fi
}

function config_simplecov_formatter() {
  if [[ "$BASH_COVERAGE_FORMATTERS" ]]
  then
    echo "  formatter SimpleCov::Formatter::MultiFormatter.new(["
      for class in $(simplecov_formatter_class_list)
      do
        echo "    ${class},"
      done
      echo "    SimpleCov::Formatter::CoberturaFormatter"
    echo "  ])"
  else
    echo "  formatter SimpleCov::Formatter::CoberturaFormatter"
  fi
}

function config_simplecov() {
  TARGET_FILE=$1/.simplecov
  if [[ -f "${TARGET_FILE}" ]]
  then
    log_info ".simplecov file found: use it (explicit configuration)"
  else
    log_info "No .simplecov file found: generate it (implicit configuration)"
    {
      simplecov_require_section ;
      echo "SimpleCov.start do" ;
      echo "  coverage_dir 'reports'" ;
      echo "  track_files '${BASH_COVERAGE_TRACK_FILES}'"
      config_simplecov_formatter
      # shellcheck disable=SC2068
      for filter in ${2//,/ }
      do
        if [[ "$filter" ]]
        then
          echo "  add_filter \"$filter\""
        fi
      done
      echo "end"
    } > "${TARGET_FILE}"
  fi
}

function simplecov_require_section(){
  echo "require 'simplecov'";
  for library in $(simplecov_package_list)
  do
    if [[ -n "$library" ]]; then
      echo "require '$library'"
    fi
  done
  echo "require 'simplecov-cobertura'";
}

function simplecov_package_list(){
  for formatter in ${BASH_COVERAGE_FORMATTERS//,/ }
  do
    if [[ "$formatter" =~ "@" ]]
    then
      # explicit package: strip classname
      echo "${formatter%@*}"
    fi
  done
}

function simplecov_formatter_class_list(){
  for formatter in ${BASH_COVERAGE_FORMATTERS//,/ }
  do
    if [[ "$formatter" =~ "@" ]]
    then
      # @ found: strip package name
      echo "${formatter#*@}"
    else
      echo "$formatter"
    fi
  done
}

function run_bats() {
  if [[ "${BASH_COVERAGE_ENABLED}" == "true" ]]
  then
    install_bashcov
    # prevent shell expension of string values
    set -f
    config_simplecov "${CI_PROJECT_DIR}" ".git/, ${BASH_BATS_TESTS}/, ${BASH_COVERAGE_FILTERS}" "${BASH_COVERAGE_FORMATTERS}"
    set +f
    bashcov -- bats "$@" || exit_code=$?
    mv "reports/coverage.xml" "${CI_PROJECT_DIR}/reports/bash-coverage.cobertura.xml"
    # shellcheck disable=SC2086
    exit $exit_code
  else
    bats "$@"
  fi
}

function glob_expand() {
  for f in "$@"; do
    if [[ "$f" == *[*?[]* ]]; then
        # expand pattern with * or ? or [
        find . -path "$f" -type f
    elif [[ -f "$f" ]]; then
      echo "$f"
    else
      log_error "File not found: $f"
      exit 1
    fi
  done
}

unscope_variables
eval_all_secrets

# ENDSCRIPT