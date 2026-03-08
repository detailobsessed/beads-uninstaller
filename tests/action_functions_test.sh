#!/usr/bin/env bash
# bashunit: no-parallel-tests

function set_up() {
  # shellcheck source=../beads-uninstaller.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/beads-uninstaller.sh"
  reset_state
  TEST_DIR=$(bashunit::temp_dir)
}

function tear_down() {
  : # bashunit::temp_dir auto-cleans
}

# ── run_rm ───────────────────────────────────────────────────────────────

function test_run_rm_dry_run_does_not_delete() {
  APPLY=0
  local file="$TEST_DIR/keep_me.txt"
  echo "content" > "$file"

  run_rm "$file"

  assert_file_exists "$file"
}

function test_run_rm_dry_run_increments_stat_removed() {
  APPLY=0
  local file="$TEST_DIR/file.txt"
  echo "content" > "$file"

  run_rm "$file"

  assert_same "1" "$STAT_REMOVED"
}

function test_run_rm_apply_deletes_file() {
  APPLY=1
  local file="$TEST_DIR/delete_me.txt"
  echo "content" > "$file"

  run_rm "$file"

  assert_file_not_exists "$file"
}

function test_run_rm_apply_deletes_directory() {
  APPLY=1
  local dir="$TEST_DIR/delete_me_dir"
  mkdir -p "$dir"
  echo "content" > "$dir/file.txt"

  run_rm "$dir"

  assert_directory_not_exists "$dir"
}

function test_run_rm_apply_increments_stat_removed() {
  APPLY=1
  local file="$TEST_DIR/file.txt"
  echo "content" > "$file"

  run_rm "$file"

  assert_same "1" "$STAT_REMOVED"
}

function test_run_rm_nonexistent_does_nothing() {
  APPLY=1
  run_rm "$TEST_DIR/nonexistent"
  assert_same "0" "$STAT_REMOVED"
}

# ── run_mv ───────────────────────────────────────────────────────────────

function test_run_mv_dry_run_does_not_move() {
  APPLY=0
  local src="$TEST_DIR/src.txt"
  local dst="$TEST_DIR/dst.txt"
  echo "content" > "$src"

  run_mv "$src" "$dst"

  assert_file_exists "$src"
  assert_file_not_exists "$dst"
}

function test_run_mv_dry_run_increments_stat_changed() {
  APPLY=0
  run_mv "$TEST_DIR/src" "$TEST_DIR/dst"
  assert_same "1" "$STAT_CHANGED"
}

function test_run_mv_apply_moves_file() {
  APPLY=1
  local src="$TEST_DIR/src.txt"
  local dst="$TEST_DIR/dst.txt"
  echo "content" > "$src"

  run_mv "$src" "$dst"

  assert_file_not_exists "$src"
  assert_file_exists "$dst"
}

function test_run_mv_apply_increments_stat_changed() {
  APPLY=1
  local src="$TEST_DIR/src.txt"
  local dst="$TEST_DIR/dst.txt"
  echo "content" > "$src"

  run_mv "$src" "$dst"

  assert_same "1" "$STAT_CHANGED"
}

# ── run ──────────────────────────────────────────────────────────────────

function test_run_dry_run_does_not_execute() {
  APPLY=0
  local file="$TEST_DIR/should_not_exist.txt"

  run touch "$file"

  assert_file_not_exists "$file"
}

function test_run_apply_executes_command() {
  APPLY=1
  local file="$TEST_DIR/should_exist.txt"

  run touch "$file"

  assert_file_exists "$file"
}

function test_run_tracks_kill_as_daemon_stat() {
  APPLY=0
  STAT_DAEMONS=0
  run kill -0 $$ 2>/dev/null || true
  assert_same "1" "$STAT_DAEMONS"
}

function test_run_tracks_git_as_changed_stat() {
  APPLY=0
  STAT_CHANGED=0
  run git version 2>/dev/null || true
  assert_same "1" "$STAT_CHANGED"
}

# ── rmdir_if_empty ───────────────────────────────────────────────────────

function test_rmdir_if_empty_removes_empty_dir() {
  APPLY=1
  local dir="$TEST_DIR/empty_dir"
  mkdir -p "$dir"

  rmdir_if_empty "$dir"

  assert_directory_not_exists "$dir"
}

function test_rmdir_if_empty_keeps_nonempty_dir() {
  APPLY=1
  local dir="$TEST_DIR/nonempty_dir"
  mkdir -p "$dir"
  echo "content" > "$dir/file.txt"

  rmdir_if_empty "$dir"

  assert_directory_exists "$dir"
}

function test_rmdir_if_empty_noop_for_nonexistent() {
  APPLY=1
  rmdir_if_empty "$TEST_DIR/nonexistent"
  assert_successful_code
}
