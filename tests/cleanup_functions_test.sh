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

# ── cleanup_gitattributes ────────────────────────────────────────────────

function test_cleanup_gitattributes_removes_merge_beads_lines() {
  local repo="$TEST_DIR/repo"
  mkdir -p "$repo"
  printf '*.jsonl merge=beads\n*.txt text\n' > "$repo/.gitattributes"

  cleanup_gitattributes "$repo"

  assert_file_exists "$repo/.gitattributes"
  assert_file_not_contains "$repo/.gitattributes" "merge=beads"
  assert_file_contains "$repo/.gitattributes" "*.txt text"
}

function test_cleanup_gitattributes_removes_file_if_only_beads() {
  local repo="$TEST_DIR/repo"
  mkdir -p "$repo"
  printf '*.jsonl merge=beads\n' > "$repo/.gitattributes"

  cleanup_gitattributes "$repo"

  assert_file_not_exists "$repo/.gitattributes"
}

function test_cleanup_gitattributes_strips_beads_comment_lines() {
  local repo="$TEST_DIR/repo"
  mkdir -p "$repo"
  printf '# Use bd merge for beads JSONL files\n*.jsonl merge=beads\n*.txt text\n' > "$repo/.gitattributes"

  cleanup_gitattributes "$repo"

  assert_file_exists "$repo/.gitattributes"
  assert_file_not_contains "$repo/.gitattributes" "bd merge"
  assert_file_not_contains "$repo/.gitattributes" "merge=beads"
  assert_file_contains "$repo/.gitattributes" "*.txt text"
}

function test_cleanup_gitattributes_removes_whitespace_only_file() {
  local repo="$TEST_DIR/repo"
  mkdir -p "$repo"
  printf '# Use bd merge for beads JSONL files\n*.jsonl merge=beads\n' > "$repo/.gitattributes"

  cleanup_gitattributes "$repo"

  assert_file_not_exists "$repo/.gitattributes"
}

function test_cleanup_gitattributes_noop_if_no_beads() {
  local repo="$TEST_DIR/repo"
  mkdir -p "$repo"
  printf '*.txt text\n' > "$repo/.gitattributes"

  cleanup_gitattributes "$repo"

  assert_file_exists "$repo/.gitattributes"
  assert_file_contains "$repo/.gitattributes" "*.txt text"
}

function test_cleanup_gitattributes_noop_if_no_file() {
  local repo="$TEST_DIR/repo"
  mkdir -p "$repo"

  cleanup_gitattributes "$repo"
  assert_successful_code
}

# ── cleanup_exclude ──────────────────────────────────────────────────────

function test_cleanup_exclude_removes_beads_entries() {
  local git_dir="$TEST_DIR/.git"
  mkdir -p "$git_dir/info"
  printf '# Beads stealth mode\n.beads/\n.beads/issues.jsonl\n.claude/settings.local.json\n**/RECOVERY*.md\n**/SESSION*.md\nkeep_this\n' > "$git_dir/info/exclude"

  cleanup_exclude "$git_dir"

  assert_file_exists "$git_dir/info/exclude"
  assert_file_contains "$git_dir/info/exclude" "keep_this"
  assert_file_not_contains "$git_dir/info/exclude" ".beads/"
  assert_file_not_contains "$git_dir/info/exclude" "Beads stealth"
  assert_file_not_contains "$git_dir/info/exclude" "RECOVERY"
  assert_file_not_contains "$git_dir/info/exclude" "SESSION"
}

function test_cleanup_exclude_removes_file_if_only_beads() {
  local git_dir="$TEST_DIR/.git"
  mkdir -p "$git_dir/info"
  printf '# Beads stealth mode\n.beads/\n' > "$git_dir/info/exclude"

  cleanup_exclude "$git_dir"

  assert_file_not_exists "$git_dir/info/exclude"
}

function test_cleanup_exclude_noop_if_no_file() {
  local git_dir="$TEST_DIR/.git"
  mkdir -p "$git_dir/info"

  cleanup_exclude "$git_dir"
  assert_successful_code
}

# ── cleanup_agents_file ──────────────────────────────────────────────────

function test_cleanup_agents_file_strips_beads_integration_block() {
  local file="$TEST_DIR/AGENTS.md"
  printf '# My Project\n\nSome instructions.\n\n<!-- BEGIN BEADS INTEGRATION -->\nBeads stuff here\n<!-- END BEADS INTEGRATION -->\n\n## Other Section\n\nMore content.\n' > "$file"

  cleanup_agents_file "$file"

  assert_file_exists "$file"
  assert_file_contains "$file" "My Project"
  assert_file_contains "$file" "Other Section"
  assert_file_not_contains "$file" "BEGIN BEADS"
  assert_file_not_contains "$file" "Beads stuff"
}

function test_cleanup_agents_file_strips_landing_the_plane_section() {
  local file="$TEST_DIR/AGENTS.md"
  printf '# My Project\n\nCustom instructions here.\n\n## Landing the Plane (Session Completion)\n\nRun bd sync and git pull --rebase.\n' > "$file"

  cleanup_agents_file "$file"

  assert_file_exists "$file"
  assert_file_contains "$file" "My Project"
  assert_file_not_contains "$file" "Landing the Plane"
}

function test_cleanup_agents_file_removes_empty_result() {
  local file="$TEST_DIR/AGENTS.md"
  printf '<!-- BEGIN BEADS INTEGRATION -->\nOnly beads content\n<!-- END BEADS INTEGRATION -->\n' > "$file"

  cleanup_agents_file "$file"

  assert_file_not_exists "$file"
}

function test_cleanup_agents_file_removes_fully_beads_generated() {
  local file="$TEST_DIR/AGENTS.md"
  printf '# Agent Instructions\n\nThis project uses **bd** (beads). Run \`bd onboard\` to get started.\n\n## Quick Reference\n\n```bash\nbd ready\nbd show <id>\nbd update <id>\nbd close <id>\nbd sync\n```\n' > "$file"

  cleanup_agents_file "$file"

  assert_file_not_exists "$file"
}

function test_cleanup_agents_file_strips_quick_reference_section() {
  local file="$TEST_DIR/AGENTS.md"
  printf '# My Project\n\nCustom rules here.\n\n## Quick Reference\n\n```bash\nbd ready\nbd show <id>\nbd close <id>\nbd sync\n```\n' > "$file"

  cleanup_agents_file "$file"

  assert_file_exists "$file"
  assert_file_contains "$file" "Custom rules"
  assert_file_not_contains "$file" "Quick Reference"
  assert_file_not_contains "$file" "bd ready"
}

function test_cleanup_agents_file_strips_bd_intro_line() {
  local file="$TEST_DIR/AGENTS.md"
  printf '# Agent Instructions\n\nThis project uses **bd** (beads) for issue tracking. Run \`bd onboard\` to get started.\n\nOur own rules.\n' > "$file"

  cleanup_agents_file "$file"

  assert_file_exists "$file"
  assert_file_not_contains "$file" "bd"
  assert_file_not_contains "$file" "beads"
  assert_file_contains "$file" "Our own rules"
}

function test_cleanup_agents_file_noop_if_no_beads() {
  local file="$TEST_DIR/AGENTS.md"
  printf '# My Project\n\nNormal content.\n' > "$file"
  cp "$file" "$file.expected"

  cleanup_agents_file "$file"

  assert_files_equals "$file.expected" "$file"
}

function test_cleanup_agents_file_noop_if_no_file() {
  cleanup_agents_file "$TEST_DIR/nonexistent"
  assert_successful_code
}

function test_cleanup_agents_file_warns_when_python3_missing() {
  local file="$TEST_DIR/AGENTS.md"
  printf '<!-- BEGIN BEADS INTEGRATION -->\nBeads\n<!-- END BEADS INTEGRATION -->\n' > "$file"

  # Must use subshell — can't hide python3 from /usr/bin on macOS
  local output
  output=$(PATH="/nonexistent_$$" cleanup_agents_file "$file" 2>&1)

  assert_file_exists "$file"
  assert_contains "python3 not found" "$output"
}

function test_cleanup_agents_file_dry_run_does_not_modify() {
  APPLY=0
  local file="$TEST_DIR/AGENTS.md"
  printf '<!-- BEGIN BEADS INTEGRATION -->\nBeads stuff\n<!-- END BEADS INTEGRATION -->\n' > "$file"

  cleanup_agents_file "$file"

  assert_file_contains "$file" "BEGIN BEADS"
}

# ── cleanup_settings_json ────────────────────────────────────────────────

function test_cleanup_settings_json_removes_bd_prime_hooks() {
  local file="$TEST_DIR/settings.json"
  cat > "$file" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {"command": "bd prime"}
        ]
      }
    ]
  }
}
JSON

  cleanup_settings_json "$file" "claude"

  assert_file_exists "$file"
  assert_file_not_contains "$file" "bd prime"
}

function test_cleanup_settings_json_removes_bd_onboard_prompt() {
  local file="$TEST_DIR/settings.json"
  cat > "$file" <<'JSON'
{
  "prompt": "Before starting any work, run 'bd onboard' to understand the current project state and available issues."
}
JSON

  cleanup_settings_json "$file" "claude"

  assert_file_exists "$file"
  assert_file_not_contains "$file" "bd onboard"
}

function test_cleanup_settings_json_preserves_non_beads_content() {
  local file="$TEST_DIR/settings.json"
  cat > "$file" <<'JSON'
{
  "prompt": "Be helpful.",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {"command": "echo hello"}
        ]
      }
    ]
  }
}
JSON
  cp "$file" "$file.expected"

  cleanup_settings_json "$file" "claude"

  assert_files_equals "$file.expected" "$file"
}

function test_cleanup_settings_json_removes_bd_prime_stealth() {
  local file="$TEST_DIR/settings.json"
  cat > "$file" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {"command": "bd prime --stealth"}
        ]
      }
    ]
  }
}
JSON

  cleanup_settings_json "$file" "claude"

  assert_file_exists "$file"
  assert_file_not_contains "$file" "bd prime"
}

function test_cleanup_settings_json_gemini_pre_compress() {
  local file="$TEST_DIR/settings.json"
  cat > "$file" <<'JSON'
{
  "hooks": {
    "PreCompress": [
      {
        "hooks": [
          {"command": "bd prime"}
        ]
      }
    ]
  }
}
JSON

  cleanup_settings_json "$file" "gemini"

  assert_file_exists "$file"
  assert_file_not_contains "$file" "bd prime"
}

function test_cleanup_settings_json_handles_invalid_json() {
  local file="$TEST_DIR/settings.json"
  echo "not valid json{" > "$file"

  # Avoid $() subshell so coverage tracks
  cleanup_settings_json "$file" "claude" > "$TEST_DIR/output.txt" 2>&1 || true

  assert_file_exists "$file"
  assert_file_contains "$TEST_DIR/output.txt" "Skipping"
}

function test_cleanup_settings_json_warns_when_python3_missing() {
  local file="$TEST_DIR/settings.json"
  cat > "$file" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {"command": "bd prime"}
        ]
      }
    ]
  }
}
JSON

  # Must use subshell — can't hide python3 from /usr/bin on macOS
  local output
  output=$(PATH="/nonexistent_$$" cleanup_settings_json "$file" "claude" 2>&1)

  assert_file_exists "$file"
  assert_contains "python3 not found" "$output"
}

function test_cleanup_settings_json_noop_if_no_file() {
  cleanup_settings_json "$TEST_DIR/nonexistent.json" "claude"
  assert_successful_code
}

function test_cleanup_settings_json_dry_run_does_not_modify() {
  APPLY=0
  local file="$TEST_DIR/settings.json"
  cat > "$file" <<'JSON'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {"command": "bd prime"}
        ]
      }
    ]
  }
}
JSON

  cleanup_settings_json "$file" "claude"

  assert_file_contains "$file" "bd prime"
}
