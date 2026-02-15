#!/usr/bin/env bash

function set_up() {
  reset_state
  APPLY=1
  TEST_DIR=$(mktemp -d)
  REAL_HOME="$HOME"
  export HOME="$TEST_DIR"
  export GIT_CONFIG_GLOBAL="$TEST_DIR/.gitconfig"
  mkdir -p "$HOME"

  # Initialize minimal git config
  git config --global user.name "Test User"
  git config --global user.email "test@example.com"
}

function tear_down() {
  export HOME="$REAL_HOME"
  unset GIT_CONFIG_GLOBAL
  rm -rf "$TEST_DIR"
}

# ── Tests for cleanup_global_git_config ─────────────────────────────────────

function test_cleanup_global_git_config_removes_merge_beads() {
  git config --global merge.beads.driver "bd merge-driver %O %A %B %P"
  git config --global merge.beads.name "Beads JSONL merge driver"

  cleanup_global_git_config

  local driver
  driver="$(git config --global --get merge.beads.driver 2>/dev/null || echo "UNSET")"
  assert_same "UNSET" "$driver"

  local name
  name="$(git config --global --get merge.beads.name 2>/dev/null || echo "UNSET")"
  assert_same "UNSET" "$name"
}

function test_cleanup_global_git_config_removes_beads_keys() {
  git config --global beads.role "dev"
  git config --global beads.backend "anthropic"
  git config --global beads.autocommit "true"

  cleanup_global_git_config

  local role
  role="$(git config --global --get beads.role 2>/dev/null || echo "UNSET")"
  assert_same "UNSET" "$role"

  local backend
  backend="$(git config --global --get beads.backend 2>/dev/null || echo "UNSET")"
  assert_same "UNSET" "$backend"

  local autocommit
  autocommit="$(git config --global --get beads.autocommit 2>/dev/null || echo "UNSET")"
  assert_same "UNSET" "$autocommit"
}

function test_cleanup_global_git_config_removes_beads_hooks_path() {
  git config --global core.hooksPath ".beads-hooks"

  cleanup_global_git_config

  local hp
  hp="$(git config --global --get core.hooksPath 2>/dev/null || echo "UNSET")"
  assert_same "UNSET" "$hp"
}

function test_cleanup_global_git_config_preserves_non_beads_hooks_path() {
  git config --global core.hooksPath ".githooks"

  cleanup_global_git_config

  local hp
  hp="$(git config --global --get core.hooksPath 2>/dev/null || true)"
  assert_same ".githooks" "$hp"
}

function test_cleanup_global_git_config_dry_run_preserves() {
  APPLY=0
  git config --global merge.beads.driver "bd merge-driver %O %A %B %P"
  git config --global beads.role "dev"

  cleanup_global_git_config

  local driver
  driver="$(git config --global --get merge.beads.driver 2>/dev/null || true)"
  assert_not_empty "$driver"

  local role
  role="$(git config --global --get beads.role 2>/dev/null || true)"
  assert_not_empty "$role"
}

# ── Tests for cleanup_global_gitignore (with real git config) ───────────────

function test_cleanup_global_gitignore_cleans_configured_excludesfile() {
  local ignore_file="$TEST_DIR/.gitignore_global"
  printf '# Beads stealth mode\n.beads/\n.claude/settings.local.json\n*.pyc\n' > "$ignore_file"
  git config --global core.excludesfile "$ignore_file"

  cleanup_global_gitignore

  assert_file_exists "$ignore_file"
  assert_file_not_contains "$ignore_file" ".beads/"
  assert_file_not_contains "$ignore_file" "Beads stealth"
  assert_file_contains "$ignore_file" "*.pyc"
}

function test_cleanup_global_gitignore_expands_tilde() {
  local ignore_file="$TEST_DIR/.gitignore_global"
  printf '.beads/\n*.log\n' > "$ignore_file"
  git config --global core.excludesfile "~/.gitignore_global"

  cleanup_global_gitignore

  assert_file_exists "$ignore_file"
  assert_file_not_contains "$ignore_file" ".beads/"
  assert_file_contains "$ignore_file" "*.log"
}

function test_cleanup_global_gitignore_uses_fallback_location() {
  # Don't set core.excludesfile; rely on fallback to ~/.gitignore_global
  local ignore_file="$TEST_DIR/.gitignore_global"
  printf '.beads/\n.DS_Store\n' > "$ignore_file"

  cleanup_global_gitignore

  assert_file_exists "$ignore_file"
  assert_file_not_contains "$ignore_file" ".beads/"
  assert_file_contains "$ignore_file" ".DS_Store"
}

function test_cleanup_global_gitignore_removes_file_if_only_beads() {
  local ignore_file="$TEST_DIR/.gitignore_global"
  printf '# Beads stealth mode\n.beads/\n.claude/settings.local.json\n' > "$ignore_file"
  git config --global core.excludesfile "$ignore_file"

  cleanup_global_gitignore

  assert_file_not_exists "$ignore_file"
}

function test_cleanup_global_gitignore_preserves_non_beads_patterns() {
  local ignore_file="$TEST_DIR/.gitignore_global"
  printf '.DS_Store\n*.swp\n.beads/\nnode_modules/\n.claude/settings.local.json\n*.pyc\n' > "$ignore_file"
  git config --global core.excludesfile "$ignore_file"

  cleanup_global_gitignore

  assert_file_exists "$ignore_file"
  assert_file_not_contains "$ignore_file" ".beads/"
  assert_file_not_contains "$ignore_file" ".claude/settings.local.json"
  assert_file_contains "$ignore_file" ".DS_Store"
  assert_file_contains "$ignore_file" "*.swp"
  assert_file_contains "$ignore_file" "node_modules/"
  assert_file_contains "$ignore_file" "*.pyc"
}

function test_cleanup_global_gitignore_dry_run_preserves() {
  APPLY=0
  local ignore_file="$TEST_DIR/.gitignore_global"
  printf '.beads/\n*.log\n' > "$ignore_file"
  git config --global core.excludesfile "$ignore_file"

  cleanup_global_gitignore

  assert_file_contains "$ignore_file" ".beads/"
  assert_file_contains "$ignore_file" "*.log"
}
