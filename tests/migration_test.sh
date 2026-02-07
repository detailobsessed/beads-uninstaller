#!/usr/bin/env bash

function set_up() {
  reset_state
  APPLY=1
  MIGRATE_TK=1
  TEST_DIR=$(mktemp -d)
}

function tear_down() {
  rm -rf "$TEST_DIR"
}

# ── ensure_tk_installed ──────────────────────────────────────────────────

function test_ensure_tk_installed_returns_0_when_tk_exists() {
  bashunit::mock tk echo "tk version 1.0"

  ensure_tk_installed

  assert_successful_code
}

function test_ensure_tk_installed_fails_when_tk_unavailable() {
  # Hide real tk and brew from PATH so installation fails
  local saved_path="$PATH"
  PATH="/usr/bin:/bin"

  local rc=0
  ensure_tk_installed || rc=$?

  PATH="$saved_path"
  assert_same "1" "$rc"
}

# ── migrate_repos_to_tk ─────────────────────────────────────────────────

function test_migrate_repos_to_tk_skipped_when_flag_not_set() {
  MIGRATE_TK=0
  local roots_file="$TEST_DIR/roots.txt"
  echo "/some/repo" > "$roots_file"

  migrate_repos_to_tk "$roots_file"

  assert_same "0" "$MIGRATE_COUNT"
}

function test_migrate_repos_to_tk_dry_run_does_not_migrate() {
  APPLY=0
  local repo="$TEST_DIR/myrepo"
  mkdir -p "$repo/.beads"
  echo '{}' > "$repo/.beads/issues.jsonl"
  local roots_file="$TEST_DIR/roots.txt"
  echo "$repo" > "$roots_file"

  migrate_repos_to_tk "$roots_file"

  assert_same "0" "$MIGRATE_COUNT"
}

function test_migrate_repos_to_tk_finds_repos_with_beads_data() {
  local repo1="$TEST_DIR/repo1"
  local repo2="$TEST_DIR/repo2"
  mkdir -p "$repo1/.beads" "$repo2"
  echo '{}' > "$repo1/.beads/issues.jsonl"

  local roots_file="$TEST_DIR/roots.txt"
  printf '%s\n%s\n' "$repo1" "$repo2" > "$roots_file"

  # Mock tk as available and migrate-beads as successful
  bashunit::mock tk echo "Migrated: issue-1"

  migrate_repos_to_tk "$roots_file"

  assert_same "1" "$MIGRATE_COUNT"
}

function test_migrate_repos_to_tk_handles_no_beads_data() {
  local repo="$TEST_DIR/myrepo"
  mkdir -p "$repo"
  local roots_file="$TEST_DIR/roots.txt"
  echo "$repo" > "$roots_file"

  migrate_repos_to_tk "$roots_file"

  assert_same "0" "$MIGRATE_COUNT"
}

function test_migrate_repos_to_tk_warns_when_tk_unavailable() {
  local saved_path="$PATH"
  PATH="/usr/bin:/bin"

  local repo="$TEST_DIR/myrepo"
  mkdir -p "$repo/.beads"
  echo '{}' > "$repo/.beads/issues.jsonl"
  local roots_file="$TEST_DIR/roots.txt"
  echo "$repo" > "$roots_file"

  local output
  output=$(migrate_repos_to_tk "$roots_file" 2>&1)

  PATH="$saved_path"
  assert_contains "Skipping migration" "$output"
  assert_same "0" "$MIGRATE_COUNT"
}

function test_migrate_repos_to_tk_handles_empty_roots_file() {
  local roots_file="$TEST_DIR/roots.txt"
  touch "$roots_file"

  migrate_repos_to_tk "$roots_file"

  assert_same "0" "$MIGRATE_COUNT"
}
