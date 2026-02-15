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

# ── is_beads_hook ────────────────────────────────────────────────────────

function test_is_beads_hook_detects_bd_hooks_version() {
  local hook="$TEST_DIR/pre-commit"
  printf '#!/bin/bash\n# bd-hooks-version: 1.0\necho hook\n' > "$hook"

  is_beads_hook "$hook"
  assert_successful_code
}

function test_is_beads_hook_detects_bd_shim() {
  local hook="$TEST_DIR/pre-commit"
  printf '#!/bin/bash\nbd-shim pre-commit\n' > "$hook"

  is_beads_hook "$hook"
  assert_successful_code
}

function test_is_beads_hook_detects_bd_hooks_run() {
  local hook="$TEST_DIR/pre-commit"
  printf '#!/bin/bash\nbd hooks run pre-commit\n' > "$hook"

  is_beads_hook "$hook"
  assert_successful_code
}

function test_is_beads_hook_detects_bd_beads() {
  local hook="$TEST_DIR/pre-commit"
  printf '#!/bin/bash\n# bd (beads) hook\n' > "$hook"

  is_beads_hook "$hook"
  assert_successful_code
}

function test_is_beads_hook_rejects_normal_hook() {
  local hook="$TEST_DIR/pre-commit"
  printf '#!/bin/bash\necho normal hook\n' > "$hook"

  is_beads_hook "$hook"
  assert_general_error
}

function test_is_beads_hook_rejects_nonexistent_file() {
  is_beads_hook "$TEST_DIR/nonexistent"
  assert_unsuccessful_code
}

# ── restore_hook_backup ─────────────────────────────────────────────────

function test_restore_hook_backup_restores_dot_old() {
  APPLY=1
  local hook="$TEST_DIR/pre-commit"
  echo "original content" > "${hook}.old"

  restore_hook_backup "$hook"

  assert_file_exists "$hook"
  assert_file_contains "$hook" "original content"
}

function test_restore_hook_backup_removes_beads_dot_old() {
  APPLY=1
  local hook="$TEST_DIR/pre-commit"
  echo "bd-hooks-version: 1.0" > "${hook}.old"

  restore_hook_backup "$hook"

  assert_file_not_exists "${hook}.old"
  assert_file_not_exists "$hook"
}

function test_restore_hook_backup_restores_dot_backup() {
  APPLY=1
  local hook="$TEST_DIR/pre-commit"
  echo "original content" > "${hook}.backup"

  restore_hook_backup "$hook"

  assert_file_exists "$hook"
  assert_file_contains "$hook" "original content"
}

function test_restore_hook_backup_prefers_dot_old_over_dot_backup() {
  APPLY=1
  local hook="$TEST_DIR/pre-commit"
  echo "from old" > "${hook}.old"
  echo "from backup" > "${hook}.backup"

  restore_hook_backup "$hook"

  assert_file_contains "$hook" "from old"
}

function test_restore_hook_backup_restores_timestamped_backup() {
  APPLY=1
  local hook="$TEST_DIR/pre-commit"
  echo "old backup" > "${hook}.backup-20240101"
  sleep 0.1
  echo "newer backup" > "${hook}.backup-20240615"

  restore_hook_backup "$hook"

  assert_file_exists "$hook"
  assert_file_contains "$hook" "newer backup"
}

function test_restore_hook_backup_removes_beads_timestamped_backup() {
  APPLY=1
  local hook="$TEST_DIR/pre-commit"
  echo "bd-hooks-version: 1.0" > "${hook}.backup-20240101"

  restore_hook_backup "$hook"

  assert_file_not_exists "${hook}.backup-20240101"
  assert_file_not_exists "$hook"
}

# ── cleanup_hooks_dir ────────────────────────────────────────────────────

function test_cleanup_hooks_dir_removes_beads_hooks() {
  APPLY=1
  local hooks_dir="$TEST_DIR/hooks"
  mkdir -p "$hooks_dir"
  echo 'bd-hooks-version: 1.0' > "$hooks_dir/pre-commit"
  echo 'bd hooks run post-merge' > "$hooks_dir/post-merge"

  cleanup_hooks_dir "$hooks_dir"

  assert_file_not_exists "$hooks_dir/pre-commit"
  assert_file_not_exists "$hooks_dir/post-merge"
}

function test_cleanup_hooks_dir_keeps_normal_hooks() {
  APPLY=1
  local hooks_dir="$TEST_DIR/hooks"
  mkdir -p "$hooks_dir"
  echo '#!/bin/bash
echo "normal"' > "$hooks_dir/pre-commit"

  cleanup_hooks_dir "$hooks_dir"

  assert_file_exists "$hooks_dir/pre-commit"
}

function test_cleanup_hooks_dir_restores_backup_after_removing_beads() {
  APPLY=1
  local hooks_dir="$TEST_DIR/hooks"
  mkdir -p "$hooks_dir"
  echo 'bd-hooks-version: 1.0' > "$hooks_dir/pre-commit"
  echo 'original hook' > "$hooks_dir/pre-commit.old"

  cleanup_hooks_dir "$hooks_dir"

  assert_file_exists "$hooks_dir/pre-commit"
  assert_file_contains "$hooks_dir/pre-commit" "original hook"
}

function test_cleanup_hooks_dir_removes_beads_backup_files() {
  APPLY=1
  local hooks_dir="$TEST_DIR/hooks"
  mkdir -p "$hooks_dir"
  echo 'bd-hooks-version: 1.0' > "$hooks_dir/pre-commit.old"
  echo 'bd-shim' > "$hooks_dir/pre-commit.backup"

  cleanup_hooks_dir "$hooks_dir"

  assert_file_not_exists "$hooks_dir/pre-commit.old"
  assert_file_not_exists "$hooks_dir/pre-commit.backup"
}

function test_cleanup_hooks_dir_noop_for_nonexistent_dir() {
  cleanup_hooks_dir "$TEST_DIR/nonexistent"
  assert_successful_code
}

function test_cleanup_hooks_dir_handles_all_hook_types() {
  APPLY=1
  local hooks_dir="$TEST_DIR/hooks"
  mkdir -p "$hooks_dir"

  local hook_types=(pre-commit post-merge pre-push post-checkout prepare-commit-msg post-commit)
  for hook in "${hook_types[@]}"; do
    echo "bd hooks run $hook" > "$hooks_dir/$hook"
  done

  cleanup_hooks_dir "$hooks_dir"

  for hook in "${hook_types[@]}"; do
    assert_file_not_exists "$hooks_dir/$hook"
  done
}
