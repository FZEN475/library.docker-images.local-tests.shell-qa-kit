#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
  return 1
}

main() {
  local mode="${1:-}"

  case "$mode" in
    hello)
      log "hello world"
      ;;
    fail)
      error "forced failure"
      ;;
    *)
      error "usage: $0 {hello|fail}"
      ;;
  esac
}

main "$@"