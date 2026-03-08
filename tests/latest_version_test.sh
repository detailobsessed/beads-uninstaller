#!/usr/bin/env bash
# bashunit: no-parallel-tests

# Integration test: verify uninstaller handles the latest beads release.
# Requires network access — skips gracefully when offline.

_BD_BIN=""

function set_up_before_script() {
  # shellcheck source=../beads-uninstaller.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/beads-uninstaller.sh"
  _BD_BIN=$(bashunit::temp_dir)/bd

  # Detect platform
  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "$arch" in
    x86_64)  arch="amd64" ;;
    aarch64) arch="arm64" ;;
    arm64)   arch="arm64" ;;
  esac

  # Fetch latest release tag from GitHub API
  local tag
  tag=$(curl -fsSL --connect-timeout 5 \
    https://api.github.com/repos/steveyegge/beads/releases/latest 2>/dev/null \
    | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//')

  if [[ -z "$tag" ]]; then
    # No network — mark for skip
    _BD_BIN=""
    return 0
  fi

  local version="${tag#v}"
  local url="https://github.com/steveyegge/beads/releases/download/${tag}/beads_${version}_${os}_${arch}.tar.gz"

  # Download and extract bd binary
  local tmp_tar
  tmp_tar=$(bashunit::temp_file)
  if ! curl -fsSL --connect-timeout 10 "$url" -o "$tmp_tar" 2>/dev/null; then
    _BD_BIN=""
    return 0
  fi

  tar -xzf "$tmp_tar" -C "$(dirname "$_BD_BIN")" bd 2>/dev/null || {
    _BD_BIN=""
    return 0
  }
  chmod +x "$_BD_BIN"
}

function set_up() {
  reset_state
  APPLY=1
  TEST_DIR=$(cd "$(bashunit::temp_dir)" && pwd -P)
  # Sandbox: prevent bd init from touching the real system
  _REAL_HOME="$HOME"
  export HOME="$TEST_DIR/fakehome"
  mkdir -p "$HOME"
  export GIT_CONFIG_GLOBAL="$TEST_DIR/fakehome/.gitconfig"
  export XDG_CONFIG_HOME="$TEST_DIR/fakehome/.config"
}

function tear_down() {
  export HOME="$_REAL_HOME"
  unset GIT_CONFIG_GLOBAL
  unset XDG_CONFIG_HOME
}

# ── Tests ─────────────────────────────────────────────────────────────

function test_latest_bd_version_string_matches_detection() {
  if [[ -z "$_BD_BIN" || ! -x "$_BD_BIN" ]]; then
    skip "bd binary not available (offline?)"
    return
  fi

  "$_BD_BIN" version > "$TEST_DIR/version.txt" 2>&1 || true
  assert_file_contains "$TEST_DIR/version.txt" "bd version"
}

function test_latest_bd_init_detected_by_scan() {
  if [[ -z "$_BD_BIN" || ! -x "$_BD_BIN" ]]; then
    skip "bd binary not available (offline?)"
    return
  fi

  local repo="$TEST_DIR/project"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@test.com"
  git -C "$repo" config user.name "Test"

  # Initialize beads in the repo (use -q to suppress output)
  (cd "$repo" && "$_BD_BIN" init -q) > /dev/null 2>&1 || true

  # Our scanner should find this repo
  local roots_file
  roots_file=$(bashunit::temp_file)
  ROOTS=("$repo")
  scan_roots "$roots_file"

  assert_file_exists "$roots_file"
  # Use basename to avoid macOS /var vs /private/var symlink mismatch
  assert_file_contains "$roots_file" "project"
}

function test_latest_bd_init_fully_cleaned_by_uninstaller() {
  if [[ -z "$_BD_BIN" || ! -x "$_BD_BIN" ]]; then
    skip "bd binary not available (offline?)"
    return
  fi

  local repo="$TEST_DIR/project"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@test.com"
  git -C "$repo" config user.name "Test"

  # Initialize beads
  (cd "$repo" && "$_BD_BIN" init -q) > /dev/null 2>&1 || true

  # Run the uninstaller
  cleanup_repo "$repo"

  # Core beads artifacts should be gone
  assert_directory_not_exists "$repo/.beads"
  assert_directory_not_exists "$repo/.beads-hooks"

  # Merge driver config should be gone
  git -C "$repo" config --get merge.beads.driver 2>/dev/null
  assert_exit_code "1"

  # Beads config keys should be gone
  git -C "$repo" config --get-regexp '^beads\.' 2>/dev/null
  assert_exit_code "1"

  # No beads patterns in gitattributes
  if [[ -f "$repo/.gitattributes" ]]; then
    assert_file_not_contains "$repo/.gitattributes" "beads"
  fi
}
