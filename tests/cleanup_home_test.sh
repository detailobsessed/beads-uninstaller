#!/usr/bin/env bash
# bashunit: no-parallel-tests

function set_up() {
  # shellcheck source=../beads-uninstaller.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/beads-uninstaller.sh"
  reset_state
  APPLY=1
  TEST_DIR=$(bashunit::temp_dir)
  # Override HOME for test isolation
  REAL_HOME="$HOME"
  export HOME="$TEST_DIR/fakehome"
  mkdir -p "$HOME"
}

function tear_down() {
  export HOME="$REAL_HOME"
}

# ── cleanup_global_gitignore ─────────────────────────────────────────────

function test_cleanup_global_gitignore_strips_beads_entries() {
  mkdir -p "$HOME/.config/git"
  printf '# Beads stealth mode\n.beads/\n.claude/settings.local.json\nnode_modules/\n' > "$HOME/.config/git/ignore"

  cleanup_global_gitignore

  assert_file_exists "$HOME/.config/git/ignore"
  assert_file_contains "$HOME/.config/git/ignore" "node_modules"
  assert_file_not_contains "$HOME/.config/git/ignore" "Beads stealth"
  assert_file_not_contains "$HOME/.config/git/ignore" ".beads/"
}

function test_cleanup_global_gitignore_removes_file_if_only_beads() {
  mkdir -p "$HOME/.config/git"
  printf '# Beads stealth mode\n.beads/\n' > "$HOME/.config/git/ignore"

  cleanup_global_gitignore

  assert_file_not_exists "$HOME/.config/git/ignore"
}

function test_cleanup_global_gitignore_noop_if_no_file() {
  cleanup_global_gitignore
  assert_successful_code
}

function test_cleanup_global_gitignore_uses_git_config_excludesfile() {
  mkdir -p "$HOME"
  local ignore_file="$HOME/.my_gitignore"
  printf '# Beads stealth mode\n.beads/\nkeep_this\n' > "$ignore_file"

  # Mock git: here-string form returns just the path (no arg appending)
  bashunit::mock git <<< "$ignore_file"

  cleanup_global_gitignore

  assert_file_exists "$ignore_file"
  assert_file_contains "$ignore_file" "keep_this"
  assert_file_not_contains "$ignore_file" "Beads stealth"
}

function test_cleanup_global_gitignore_handles_tilde_path() {
  local ignore_file="$HOME/.gitignore_global"
  printf '# Beads stealth mode\n.beads/\nkeep_this\n' > "$ignore_file"

  # Mock git to return a tilde-prefixed path like git config often does
  bashunit::mock git <<< "~/.gitignore_global"

  cleanup_global_gitignore

  assert_file_exists "$ignore_file"
  assert_file_contains "$ignore_file" "keep_this"
  assert_file_not_contains "$ignore_file" "Beads stealth"
}

# ── cleanup_home ─────────────────────────────────────────────────────────

function test_cleanup_home_removes_dot_beads() {
  mkdir -p "$HOME/.beads"
  echo "data" > "$HOME/.beads/issues.jsonl"

  cleanup_home

  assert_directory_not_exists "$HOME/.beads"
}

function test_cleanup_home_removes_config_bd() {
  mkdir -p "$HOME/.config/bd"
  echo "config" > "$HOME/.config/bd/config.yml"

  cleanup_home

  assert_directory_not_exists "$HOME/.config/bd"
}

function test_cleanup_home_removes_beads_planning_if_has_beads_subdir() {
  mkdir -p "$HOME/.beads-planning/.beads"
  echo "plan" > "$HOME/.beads-planning/.beads/data"

  cleanup_home

  assert_directory_not_exists "$HOME/.beads-planning"
}

function test_cleanup_home_keeps_beads_planning_without_beads_subdir() {
  mkdir -p "$HOME/.beads-planning"
  echo "plan" > "$HOME/.beads-planning/notes.md"

  cleanup_home

  assert_directory_exists "$HOME/.beads-planning"
}

function test_cleanup_home_cleans_claude_settings() {
  mkdir -p "$HOME/.claude"
  printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"bd prime"}]}]}}\n' > "$HOME/.claude/settings.json"

  cleanup_home

  assert_file_not_contains "$HOME/.claude/settings.json" "bd prime"
}

function test_cleanup_home_cleans_gemini_settings() {
  mkdir -p "$HOME/.gemini"
  printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"bd prime"}]}]}}\n' > "$HOME/.gemini/settings.json"

  cleanup_home

  assert_file_not_contains "$HOME/.gemini/settings.json" "bd prime"
}

function test_cleanup_home_skipped_when_skip_home_set() {
  SKIP_HOME=1
  mkdir -p "$HOME/.beads"
  echo "data" > "$HOME/.beads/issues.jsonl"

  cleanup_home

  assert_directory_exists "$HOME/.beads"
}

function test_cleanup_home_dry_run_preserves_everything() {
  APPLY=0
  mkdir -p "$HOME/.beads"
  echo "data" > "$HOME/.beads/issues.jsonl"
  mkdir -p "$HOME/.config/bd"

  cleanup_home

  assert_directory_exists "$HOME/.beads"
  assert_directory_exists "$HOME/.config/bd"
}
