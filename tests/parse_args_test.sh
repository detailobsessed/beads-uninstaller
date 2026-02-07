#!/usr/bin/env bash

function set_up() {
  reset_state
  TEST_DIR=$(cd "$(mktemp -d)" && pwd -P)
}

function tear_down() {
  rm -rf "$TEST_DIR"
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
  parse_args --bogus > "$TEST_DIR/output.txt" 2>&1 || true
  assert_file_contains "$TEST_DIR/output.txt" "Unknown argument"
}

function test_root_without_dir_exits() {
  parse_args --root > "$TEST_DIR/output.txt" 2>&1 || true
  assert_file_contains "$TEST_DIR/output.txt" "--root requires a directory"
}

function test_help_flag_shows_usage() {
  parse_args --help > "$TEST_DIR/output.txt" 2>&1 || true
  assert_file_contains "$TEST_DIR/output.txt" "Beads uninstall/cleanup script"
}
