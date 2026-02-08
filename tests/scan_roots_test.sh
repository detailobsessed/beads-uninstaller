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

function test_add_repo_root_handles_git_hooks_path() {
  local repo="$TEST_DIR/myproject"
  mkdir -p "$repo/.git/hooks"
  git -C "$repo" init -q
  touch "$repo/.git/hooks/pre-commit"

  local result
  result="$(add_repo_root "$repo/.git/hooks/pre-commit")"

  assert_same "$repo" "$result"
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

function test_scan_roots_finds_beads_directory() {
  local repo="$TEST_DIR/myproject"
  mkdir -p "$repo/.beads"
  echo '{}' > "$repo/.beads/issues.jsonl"
  git -C "$repo" init -q
  ROOTS=("$repo")

  local roots_file
  roots_file=$(mktemp)
  scan_roots "$roots_file"

  assert_file_contains "$roots_file" "myproject"
  rm -f "$roots_file"
}

function test_scan_roots_finds_beads_hooks_dir() {
  local repo="$TEST_DIR/myproject"
  mkdir -p "$repo/.beads-hooks"
  echo 'hook' > "$repo/.beads-hooks/pre-commit"
  git -C "$repo" init -q
  ROOTS=("$repo")

  local roots_file
  roots_file=$(mktemp)
  scan_roots "$roots_file"

  assert_file_contains "$roots_file" "myproject"
  rm -f "$roots_file"
}

function test_scan_roots_finds_aider_conf() {
  local repo="$TEST_DIR/myproject"
  mkdir -p "$repo"
  printf '# BEADS config\nbeads: true\n' > "$repo/.aider.conf.yml"
  git -C "$repo" init -q
  ROOTS=("$repo")

  local roots_file
  roots_file=$(mktemp)
  scan_roots "$roots_file"

  assert_file_contains "$roots_file" "$repo"
  rm -f "$roots_file"
}

function test_scan_roots_finds_agents_md_with_beads() {
  local repo="$TEST_DIR/myproject"
  mkdir -p "$repo"
  printf '# Project\n\n## Landing the Plane (Session Completion)\n\nbd sync\n' > "$repo/AGENTS.md"
  git -C "$repo" init -q
  ROOTS=("$repo")

  local roots_file
  roots_file=$(mktemp)
  scan_roots "$roots_file"

  assert_file_contains "$roots_file" "$repo"
  rm -f "$roots_file"
}

function test_scan_roots_finds_claude_settings() {
  local repo="$TEST_DIR/myproject"
  mkdir -p "$repo/.claude"
  printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"bd prime"}]}]}}\n' > "$repo/.claude/settings.local.json"
  git -C "$repo" init -q
  ROOTS=("$repo")

  local roots_file
  roots_file=$(mktemp)
  scan_roots "$roots_file"

  assert_file_contains "$roots_file" "myproject"
  rm -f "$roots_file"
}

function test_scan_roots_excludes_home_dotbeads() {
  # When scanning HOME itself, ~/.beads should be excluded (handled by cleanup_home)
  local fake_home="$TEST_DIR/fakehome"
  mkdir -p "$fake_home/.beads"
  echo '{}' > "$fake_home/.beads/issues.jsonl"

  local orig_home="$HOME"
  export HOME="$fake_home"
  ROOTS=("$fake_home")

  local roots_file
  roots_file=$(mktemp)
  scan_roots "$roots_file"

  export HOME="$orig_home"

  # HOME/.beads should NOT produce a root entry
  local count
  count=$(wc -l < "$roots_file" | tr -d ' ')
  assert_same "0" "$count"
  rm -f "$roots_file"
}

function test_scan_roots_finds_gemini_settings() {
  local repo="$TEST_DIR/myproject"
  mkdir -p "$repo/.gemini"
  printf '{"hooks":{}}\n' > "$repo/.gemini/settings.json"
  git -C "$repo" init -q
  ROOTS=("$repo")

  local roots_file
  roots_file=$(mktemp)
  scan_roots "$roots_file"

  assert_file_contains "$roots_file" "myproject"
  rm -f "$roots_file"
}

function test_scan_roots_finds_beads_git_hooks() {
  local repo="$TEST_DIR/myproject"
  mkdir -p "$repo/.git/hooks"
  git -C "$repo" init -q

  # Create a beads hook with the bd-shim signature
  cat > "$repo/.git/hooks/pre-commit" <<'EOF'
#!/usr/bin/env sh
# bd-shim v1
# bd-hooks-version: 0.49.3
#
# bd (beads) pre-commit hook - thin shim
exec bd hooks run pre-commit "$@"
EOF
  chmod +x "$repo/.git/hooks/pre-commit"

  ROOTS=("$repo")

  local roots_file
  roots_file=$(mktemp)
  scan_roots "$roots_file"

  assert_file_contains "$roots_file" "myproject"
  rm -f "$roots_file"
}

function test_scan_roots_finds_repo_with_only_git_hooks() {
  # Test the specific case: repo with ONLY beads hooks, no other beads artifacts
  local repo="$TEST_DIR/hooks_only"
  mkdir -p "$repo/.git/hooks"
  git -C "$repo" init -q

  # Create multiple beads hooks
  cat > "$repo/.git/hooks/post-checkout" <<'EOF'
#!/usr/bin/env sh
# bd-shim v1
# bd-hooks-version: 0.49.3
exec bd hook post-checkout "$@"
EOF

  cat > "$repo/.git/hooks/pre-push" <<'EOF'
#!/usr/bin/env sh
# bd-shim v1
exec bd hooks run pre-push "$@"
EOF

  chmod +x "$repo/.git/hooks/post-checkout"
  chmod +x "$repo/.git/hooks/pre-push"

  ROOTS=("$repo")

  local roots_file
  roots_file=$(mktemp)
  scan_roots "$roots_file"

  # Should find the repo even with no .beads/ or other artifacts
  assert_file_contains "$roots_file" "hooks_only"
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
