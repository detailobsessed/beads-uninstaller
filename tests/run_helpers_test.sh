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

# ── run() stat tracking ─────────────────────────────────────────────────

function test_run_tracks_kill_as_daemon_stat() {
  # Create a process to kill
  sleep 300 &
  local pid=$!

  run kill "$pid"

  assert_same "1" "$STAT_DAEMONS"
  wait "$pid" 2>/dev/null || true
}

function test_run_tracks_git_as_changed_stat() {
  local repo="$TEST_DIR/myrepo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config test.key testval

  run git -C "$repo" config --unset test.key

  assert_same "1" "$STAT_CHANGED"
}

function test_run_tracks_brew_as_binary_stat() {
  run brew --version

  assert_same "1" "$STAT_BINARIES"
}

function test_run_dry_run_logs_skip() {
  APPLY=0

  # Avoid $() subshell so coverage tracks
  run echo "hello" > "$TEST_DIR/output.txt" 2>&1 || true

  assert_file_contains "$TEST_DIR/output.txt" "dry-run"
}

# ── run_rm ───────────────────────────────────────────────────────────────

function test_run_rm_removes_existing_file() {
  local f="$TEST_DIR/file.txt"
  echo "data" > "$f"

  run_rm "$f"

  assert_file_not_exists "$f"
  assert_same "1" "$STAT_REMOVED"
}

function test_run_rm_removes_directory() {
  mkdir -p "$TEST_DIR/subdir"
  echo "data" > "$TEST_DIR/subdir/file.txt"

  run_rm "$TEST_DIR/subdir"

  assert_directory_not_exists "$TEST_DIR/subdir"
  assert_same "1" "$STAT_REMOVED"
}

function test_run_rm_noop_if_not_exists() {
  run_rm "$TEST_DIR/nonexistent"

  assert_same "0" "$STAT_REMOVED"
}

function test_run_rm_dry_run_increments_stat() {
  APPLY=0
  echo "data" > "$TEST_DIR/file.txt"

  run_rm "$TEST_DIR/file.txt"

  assert_file_exists "$TEST_DIR/file.txt"
  assert_same "1" "$STAT_REMOVED"
}

# ── run_mv ───────────────────────────────────────────────────────────────

function test_run_mv_moves_file() {
  echo "content" > "$TEST_DIR/src.txt"

  run_mv "$TEST_DIR/src.txt" "$TEST_DIR/dst.txt"

  assert_file_not_exists "$TEST_DIR/src.txt"
  assert_file_exists "$TEST_DIR/dst.txt"
  assert_file_contains "$TEST_DIR/dst.txt" "content"
}

function test_run_mv_dry_run_does_not_move() {
  APPLY=0
  echo "content" > "$TEST_DIR/src.txt"

  run_mv "$TEST_DIR/src.txt" "$TEST_DIR/dst.txt"

  assert_file_exists "$TEST_DIR/src.txt"
  assert_file_not_exists "$TEST_DIR/dst.txt"
}

# ── rmdir_if_empty ───────────────────────────────────────────────────────

function test_rmdir_if_empty_removes_empty_dir() {
  mkdir -p "$TEST_DIR/empty"

  rmdir_if_empty "$TEST_DIR/empty"

  assert_directory_not_exists "$TEST_DIR/empty"
}

function test_rmdir_if_empty_keeps_nonempty_dir() {
  mkdir -p "$TEST_DIR/notempty"
  echo "data" > "$TEST_DIR/notempty/file.txt"

  rmdir_if_empty "$TEST_DIR/notempty"

  assert_directory_exists "$TEST_DIR/notempty"
}

function test_rmdir_if_empty_noop_if_no_dir() {
  rmdir_if_empty "$TEST_DIR/nonexistent"
  assert_successful_code
}

# ── log helpers ──────────────────────────────────────────────────────────

function test_log_outputs_message() {
  log "test message" > "$TEST_DIR/output.txt" 2>&1
  assert_file_contains "$TEST_DIR/output.txt" "test message"
}

function test_log_action_outputs_action() {
  log_action "doing something" > "$TEST_DIR/output.txt" 2>&1
  assert_file_contains "$TEST_DIR/output.txt" "doing something"
}

function test_log_skip_outputs_skip() {
  log_skip "skipped thing" > "$TEST_DIR/output.txt" 2>&1
  assert_file_contains "$TEST_DIR/output.txt" "skipped thing"
}

function test_warn_outputs_warning() {
  warn "a warning" > "$TEST_DIR/output.txt" 2>&1
  assert_file_contains "$TEST_DIR/output.txt" "WARN"
  assert_file_contains "$TEST_DIR/output.txt" "a warning"
}
