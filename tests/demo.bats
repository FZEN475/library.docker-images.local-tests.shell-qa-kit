#!/usr/bin/env bats

setup() {
  export BATS_LIB_PATH="${BATS_LIB_PATH:-/opt/bats/libexec}"
}

load "${BATS_LIB_PATH}/bats-support/load"
load "${BATS_LIB_PATH}/bats-assert/load"

SCRIPT="scripts/demo.sh"

@test "hello prints message" {
  run "$SCRIPT" hello
  assert_success
  assert_output --partial "hello world"
}

@test "fail returns error" {
  run "$SCRIPT" fail
  assert_failure
  assert_output --partial "forced failure"
}

@test "invalid arg shows usage error" {
  run "$SCRIPT" unknown
  assert_failure
  assert_output --partial "usage:"
}