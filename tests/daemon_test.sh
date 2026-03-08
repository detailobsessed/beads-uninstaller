#!/usr/bin/env bash
# bashunit: no-parallel-tests

function set_up() {
  # shellcheck source=../beads-uninstaller.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/beads-uninstaller.sh"
  reset_state
  APPLY=1
  TEST_DIR=$(bashunit::temp_dir)
}

function tear_down() {
  : # bashunit::temp_dir auto-cleans
}

# ── stop_daemon_pid_file ─────────────────────────────────────────────────
# NOTE: Tests that spawn background processes hang in bashunit's subshell
# capture. We test the early-return paths here; the kill logic is covered
# by the integration test (main_integration_test.sh cleanup_repo path).

function test_stop_daemon_pid_file_noop_if_no_file() {
  stop_daemon_pid_file "$TEST_DIR/nonexistent.pid"
  assert_same "0" "$STAT_DAEMONS"
}

function test_stop_daemon_pid_file_noop_if_invalid_pid() {
  echo "not_a_number" > "$TEST_DIR/daemon.pid"

  stop_daemon_pid_file "$TEST_DIR/daemon.pid"

  assert_same "0" "$STAT_DAEMONS"
}

function test_stop_daemon_pid_file_noop_if_pid_not_running() {
  echo "99999" > "$TEST_DIR/daemon.pid"

  stop_daemon_pid_file "$TEST_DIR/daemon.pid"

  assert_same "0" "$STAT_DAEMONS"
}

function test_stop_daemon_pid_file_handles_whitespace_in_pid() {
  echo "  99999  " > "$TEST_DIR/daemon.pid"

  stop_daemon_pid_file "$TEST_DIR/daemon.pid"

  assert_same "0" "$STAT_DAEMONS"
}

function test_stop_daemon_pid_file_noop_if_empty_file() {
  echo "" > "$TEST_DIR/daemon.pid"

  stop_daemon_pid_file "$TEST_DIR/daemon.pid"

  assert_same "0" "$STAT_DAEMONS"
}
