#!/usr/bin/env bash

function set_up() {
  reset_state
  APPLY=1
  TEST_DIR=$(mktemp -d)
}

function tear_down() {
  rm -rf "$TEST_DIR"
}

# ── Helper: create a fake repo with beads artifacts ──────────────────────

create_beads_repo() {
  local repo="$1"
  mkdir -p "$repo"

  # Initialize a real git repo first
  git -C "$repo" init -q 2>/dev/null || true
  git -C "$repo" config merge.beads.driver "bd merge %A %O %A %B" 2>/dev/null || true
  git -C "$repo" config merge.beads.name "bd JSONL merge driver" 2>/dev/null || true

  # Create beads artifacts on top
  mkdir -p "$repo/.beads"
  mkdir -p "$repo/.beads-hooks"
  mkdir -p "$repo/.claude"
  mkdir -p "$repo/.gemini"
  mkdir -p "$repo/.cursor/rules"
  mkdir -p "$repo/.aider"

  echo '{"issues": []}' > "$repo/.beads/issues.jsonl"
  echo "daemon" > "$repo/.beads/daemon.pid"
  printf '*.jsonl merge=beads\n*.txt text\n' > "$repo/.gitattributes"
  mkdir -p "$repo/.git/info"
  printf '# Beads stealth mode\n.beads/\n' > "$repo/.git/info/exclude"
  printf '#!/bin/bash\nbd hooks run pre-commit\n' > "$repo/.git/hooks/pre-commit"
  printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"bd prime"}]}]}}\n' > "$repo/.claude/settings.local.json"
  printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"bd prime"}]}]}}\n' > "$repo/.gemini/settings.json"
  printf 'beads_rule: true\n' > "$repo/.cursor/rules/beads.mdc"
  printf '# BEADS config\nbeads: true\n' > "$repo/.aider.conf.yml"
  printf '# Beads README\nbd stuff\n' > "$repo/.aider/README.md"
  printf '# BEADS\n' > "$repo/.aider/BEADS.md"

  # AGENTS.md with beads content
  printf '# Project\n\n<!-- BEGIN BEADS INTEGRATION -->\nBeads stuff\n<!-- END BEADS INTEGRATION -->\n\n## Other\nKeep this.\n' > "$repo/AGENTS.md"
}

# ── cleanup_repo tests ───────────────────────────────────────────────────

function test_cleanup_repo_removes_beads_directories() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  assert_directory_not_exists "$repo/.beads"
  assert_directory_not_exists "$repo/.beads-hooks"
}

function test_cleanup_repo_cleans_gitattributes() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  assert_file_exists "$repo/.gitattributes"
  assert_file_not_contains "$repo/.gitattributes" "merge=beads"
  assert_file_contains "$repo/.gitattributes" "*.txt text"
}

function test_cleanup_repo_cleans_git_exclude() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  assert_file_not_contains "$repo/.git/info/exclude" ".beads/"
}

function test_cleanup_repo_removes_beads_hooks() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  assert_file_not_exists "$repo/.git/hooks/pre-commit"
}

function test_cleanup_repo_cleans_claude_settings() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  assert_file_not_contains "$repo/.claude/settings.local.json" "bd prime"
}

function test_cleanup_repo_cleans_gemini_settings() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  assert_file_not_contains "$repo/.gemini/settings.json" "bd prime"
}

function test_cleanup_repo_removes_cursor_beads_mdc() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  assert_file_not_exists "$repo/.cursor/rules/beads.mdc"
}

function test_cleanup_repo_removes_beads_aider_conf() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  assert_file_not_exists "$repo/.aider.conf.yml"
}

function test_cleanup_repo_removes_aider_beads_md() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  assert_file_not_exists "$repo/.aider/BEADS.md"
}

function test_cleanup_repo_removes_beads_aider_readme() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  assert_file_not_exists "$repo/.aider/README.md"
}

function test_cleanup_repo_preserves_non_beads_aider_conf() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"
  printf 'model: gpt-4\n' > "$repo/.aider.conf.yml"

  cleanup_repo "$repo"

  assert_file_exists "$repo/.aider.conf.yml"
  assert_file_contains "$repo/.aider.conf.yml" "model: gpt-4"
}

function test_cleanup_repo_cleans_agents_md() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  assert_file_exists "$repo/AGENTS.md"
  assert_file_not_contains "$repo/AGENTS.md" "BEGIN BEADS"
  assert_file_contains "$repo/AGENTS.md" "Keep this"
}

function test_cleanup_repo_removes_merge_driver_config() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  local driver
  driver=$(git -C "$repo" config --get merge.beads.driver 2>/dev/null || echo "UNSET")
  assert_same "UNSET" "$driver"
}

function test_cleanup_repo_tracks_repo_in_cleaned_repos() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"
  CLEANED_REPOS=()

  cleanup_repo "$repo"

  assert_same "1" "${#CLEANED_REPOS[@]}"
  assert_same "$repo" "${CLEANED_REPOS[0]}"
}

function test_cleanup_repo_increments_stats() {
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"
  STAT_REMOVED=0
  STAT_CHANGED=0

  cleanup_repo "$repo"

  assert_greater_than "0" "$STAT_REMOVED"
  assert_greater_than "0" "$STAT_CHANGED"
}

function test_cleanup_repo_noop_for_nonexistent_dir() {
  CLEANED_REPOS=()
  cleanup_repo "$TEST_DIR/nonexistent"
  assert_same "0" "${#CLEANED_REPOS[@]}"
}

function test_cleanup_repo_dry_run_preserves_everything() {
  APPLY=0
  local repo="$TEST_DIR/myproject"
  create_beads_repo "$repo"

  cleanup_repo "$repo"

  assert_directory_exists "$repo/.beads"
  assert_directory_exists "$repo/.beads-hooks"
  assert_file_exists "$repo/.cursor/rules/beads.mdc"
}
