#!/usr/bin/env bash

function set_up() {
  reset_state
}

function test_defaults_are_dry_run() {
  parse_args
  assert_same "0" "$APPLY"
  assert_same "0" "$SKIP_HOME"
  assert_same "0" "$SKIP_BINARY"
  assert_same "0" "$MIGRATE_TK"
}

function test_apply_flag() {
  parse_args --apply
  assert_same "1" "$APPLY"
}

function test_skip_home_flag() {
  parse_args --skip-home
  assert_same "1" "$SKIP_HOME"
}

function test_skip_binary_flag() {
  parse_args --skip-binary
  assert_same "1" "$SKIP_BINARY"
}

function test_migrate_tk_flag() {
  parse_args --migrate-tk
  assert_same "1" "$MIGRATE_TK"
}

function test_root_flag_adds_to_roots() {
  parse_args --root /tmp
  assert_same "1" "${#ROOTS[@]}"
  assert_same "/tmp" "${ROOTS[0]}"
}

function test_multiple_root_flags() {
  parse_args --root /tmp --root /var
  assert_same "2" "${#ROOTS[@]}"
  assert_same "/tmp" "${ROOTS[0]}"
  assert_same "/var" "${ROOTS[1]}"
}

function test_combined_flags() {
  parse_args --apply --skip-home --skip-binary --migrate-tk --root /tmp
  assert_same "1" "$APPLY"
  assert_same "1" "$SKIP_HOME"
  assert_same "1" "$SKIP_BINARY"
  assert_same "1" "$MIGRATE_TK"
  assert_same "/tmp" "${ROOTS[0]}"
}

function test_unknown_flag_exits() {
  local output
  output=$(parse_args --bogus 2>&1 || true)
  assert_contains "Unknown argument" "$output"
}

function test_root_without_dir_exits() {
  local output
  output=$(parse_args --root 2>&1 || true)
  assert_contains "--root requires a directory" "$output"
}

function test_help_flag_shows_usage() {
  local output
  output=$(parse_args --help 2>&1 || true)
  assert_contains "Beads uninstall/cleanup script" "$output"
}
