#!/usr/bin/env bash

function set_up() {
  reset_state
  TEST_DIR=$(cd "$(mktemp -d)" && pwd -P)
  REAL_HOME="$HOME"
  export HOME="$TEST_DIR/fakehome"
  mkdir -p "$HOME/.local/bin" "$HOME/go/bin"
}

function tear_down() {
  export HOME="$REAL_HOME"
  rm -rf "$TEST_DIR"
  rm -f /tmp/beads-uninstall-test-repos.txt
}

# Helper: create a minimal beads repo
create_test_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  mkdir -p "$repo/.beads"
  echo '{}' > "$repo/.beads/issues.jsonl"
  printf '*.jsonl merge=beads\n' > "$repo/.gitattributes"
  git -C "$repo" config merge.beads.driver "bd merge %A %O %A %B"
  git -C "$repo" config merge.beads.name "bd JSONL merge driver"
  git -C "$repo" config beads.role maintainer
  printf '#!/bin/bash\nbd hooks run pre-commit\n' > "$repo/.git/hooks/pre-commit"
  printf '#!/bin/bash\nbd hooks run post-merge\n' > "$repo/.git/hooks/post-merge"
  mkdir -p "$repo/.git/info"
  printf '# Beads stealth mode\n.beads/\n' > "$repo/.git/info/exclude"
}

# ── main integration ────────────────────────────────────────────────────

function test_main_dry_run_does_not_modify() {
  local repo="$TEST_DIR/project"
  create_test_repo "$repo"

  # Avoid $() subshell so coverage tracks
  main --root "$repo" --skip-home --skip-binary > "$TEST_DIR/output.txt" 2>&1 || true

  assert_file_contains "$TEST_DIR/output.txt" "DRY-RUN"
  assert_file_contains "$TEST_DIR/output.txt" "beads"
  assert_directory_exists "$repo/.beads"
  assert_file_exists "$repo/.gitattributes"
}

function test_main_apply_cleans_repo() {
  local repo="$TEST_DIR/project"
  create_test_repo "$repo"
  # Pre-cache the repo so main doesn't rely on rg path resolution
  CACHE_FILE="$TEST_DIR/cache.txt"
  echo "$repo" > "$CACHE_FILE"

  # Avoid $() subshell so coverage tracks
  main --root "$repo" --skip-home --skip-binary --apply > "$TEST_DIR/output.txt" 2>&1 || true

  assert_file_contains "$TEST_DIR/output.txt" "APPLY"
  assert_file_contains "$TEST_DIR/output.txt" "beads is no more"
  assert_directory_not_exists "$repo/.beads"
  assert_file_not_exists "$repo/.gitattributes"
  local driver
  driver=$(git -C "$repo" config --get merge.beads.driver 2>/dev/null || echo "UNSET")
  assert_same "UNSET" "$driver"
  local role
  role=$(git -C "$repo" config --get beads.role 2>/dev/null || echo "UNSET")
  assert_same "UNSET" "$role"
}

function test_main_saves_cache_on_dry_run() {
  local repo="$TEST_DIR/project"
  create_test_repo "$repo"
  CACHE_FILE="$TEST_DIR/cache.txt"

  main --root "$repo" --skip-home --skip-binary >/dev/null 2>&1

  assert_file_exists "$CACHE_FILE"
}

function test_main_reuses_cache_on_apply() {
  local repo="$TEST_DIR/project"
  create_test_repo "$repo"
  CACHE_FILE="$TEST_DIR/cache.txt"
  echo "$repo" > "$CACHE_FILE"

  # Avoid $() subshell so coverage tracks
  main --root "$repo" --skip-home --skip-binary --apply > "$TEST_DIR/output.txt" 2>&1 || true

  assert_file_contains "$TEST_DIR/output.txt" "cached scan"
  assert_directory_not_exists "$repo/.beads"
}

function test_main_deletes_cache_after_apply() {
  local repo="$TEST_DIR/project"
  create_test_repo "$repo"
  CACHE_FILE="$TEST_DIR/cache.txt"
  echo "$repo" > "$CACHE_FILE"

  main --root "$repo" --skip-home --skip-binary --apply >/dev/null 2>&1

  assert_file_not_exists "$CACHE_FILE"
}

function test_main_shows_roots_in_banner() {
  local repo="$TEST_DIR/project"
  create_test_repo "$repo"

  # Avoid $() subshell so coverage tracks
  main --root "$repo" --skip-home --skip-binary > "$TEST_DIR/output.txt" 2>&1 || true

  assert_file_contains "$TEST_DIR/output.txt" "$repo"
}

function test_main_defaults_root_to_home() {
  # With no --root, main uses $HOME
  # Avoid $() subshell so coverage tracks
  main --skip-binary > "$TEST_DIR/output.txt" 2>&1 || true

  assert_file_contains "$TEST_DIR/output.txt" "Roots"
}
