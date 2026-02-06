#!/usr/bin/env bash

function set_up() {
  reset_state
  TEST_DIR=$(cd "$(mktemp -d)" && pwd -P)
}

function tear_down() {
  rm -rf "$TEST_DIR"
}

# ── add_repo_root ────────────────────────────────────────────────────────

function test_add_repo_root_finds_git_repo_root() {
  local repo="$TEST_DIR/myproject"
  mkdir -p "$repo/subdir"
  touch "$repo/subdir/file.txt"
  git -C "$repo" init -q

  local result
  result="$(add_repo_root "$repo/subdir/file.txt")"

  assert_same "$repo" "$result"
}

function test_add_repo_root_returns_parent_of_beads_dir() {
  local repo="$TEST_DIR/myproject"
  mkdir -p "$repo/.beads"

  local result
  result="$(add_repo_root "$repo/.beads")"

  assert_same "$repo" "$result"
}

function test_add_repo_root_falls_back_to_dir_without_git() {
  local dir="$TEST_DIR/nogit/subdir"
  mkdir -p "$dir"
  touch "$dir/file.txt"

  local result
  result="$(add_repo_root "$dir/file.txt")"

  assert_same "$dir" "$result"
}

# ── scan_roots ───────────────────────────────────────────────────────────

function test_scan_roots_creates_output_file() {
  local clean_dir="$TEST_DIR/clean"
  mkdir -p "$clean_dir"
  echo "nothing here" > "$clean_dir/readme.txt"
  ROOTS=("$clean_dir")

  local roots_file
  roots_file=$(mktemp)
  scan_roots "$roots_file"

  # File should exist (even if empty when no beads traces)
  assert_file_exists "$roots_file"
  rm -f "$roots_file"
}

# ── Cache mechanism ──────────────────────────────────────────────────────

function test_cache_reused_on_apply() {
  APPLY=1
  CACHE_FILE="$TEST_DIR/cache.txt"
  echo "/tmp/cached_repo" > "$CACHE_FILE"

  # Simulate main's cache reuse logic
  local roots_file
  roots_file=$(mktemp)
  if [[ "$APPLY" -eq 1 ]] && [[ -f "$CACHE_FILE" ]] && [[ -s "$CACHE_FILE" ]]; then
    cp "$CACHE_FILE" "$roots_file"
  fi

  assert_file_contains "$roots_file" "/tmp/cached_repo"
  rm -f "$roots_file"
}

function test_cache_not_used_on_dry_run() {
  APPLY=0
  CACHE_FILE="$TEST_DIR/cache.txt"
  echo "/tmp/stale_repo" > "$CACHE_FILE"

  # Simulate main's logic: dry-run should NOT use existing cache
  local roots_file
  roots_file=$(mktemp)
  local used_cache=0
  if [[ "$APPLY" -eq 1 ]] && [[ -f "$CACHE_FILE" ]] && [[ -s "$CACHE_FILE" ]]; then
    cp "$CACHE_FILE" "$roots_file"
    used_cache=1
  fi

  assert_same "0" "$used_cache"
  rm -f "$roots_file"
}

function test_cache_ignored_when_empty() {
  APPLY=1
  CACHE_FILE="$TEST_DIR/cache.txt"
  touch "$CACHE_FILE"

  local roots_file
  roots_file=$(mktemp)
  local used_cache=0
  if [[ "$APPLY" -eq 1 ]] && [[ -f "$CACHE_FILE" ]] && [[ -s "$CACHE_FILE" ]]; then
    cp "$CACHE_FILE" "$roots_file"
    used_cache=1
  fi

  assert_same "0" "$used_cache"
  rm -f "$roots_file"
}

function test_cache_deleted_after_apply() {
  APPLY=1
  CACHE_FILE="$TEST_DIR/cache.txt"
  echo "/tmp/repo" > "$CACHE_FILE"

  # Simulate main's cleanup logic
  if [[ "$APPLY" -eq 1 ]] && [[ -f "$CACHE_FILE" ]]; then
    rm -f "$CACHE_FILE"
  fi

  assert_file_not_exists "$CACHE_FILE"
}
