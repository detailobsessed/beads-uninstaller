#!/usr/bin/env bash
# bashunit: no-parallel-tests

function set_up() {
  # shellcheck source=../beads-uninstaller.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/beads-uninstaller.sh"
  reset_state
  APPLY=1
  TEST_DIR=$(bashunit::temp_dir)
  REAL_HOME="$HOME"
  export HOME="$TEST_DIR/fakehome"
  mkdir -p "$HOME/.local/bin" "$HOME/go/bin"
}

function tear_down() {
  export HOME="$REAL_HOME"
}

function test_cleanup_binaries_skipped_when_skip_binary_set() {
  SKIP_BINARY=1

  cleanup_binaries

  assert_same "0" "$STAT_BINARIES"
}

function test_cleanup_binaries_removes_fake_bd_binary() {
  # Create a fake bd that reports as beads
  local fake_bd="$HOME/.local/bin/bd"
  cat > "$fake_bd" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "${1:-}" == "version" ]]; then
  echo "bd version 1.2.3"
  exit 0
fi
SCRIPT
  chmod +x "$fake_bd"

  cleanup_binaries

  assert_file_not_exists "$fake_bd"
  assert_greater_than "0" "$STAT_BINARIES"
}

function test_cleanup_binaries_keeps_non_beads_bd() {
  # Create a fake bd that does NOT report as beads
  local fake_bd="$HOME/.local/bin/bd"
  cat > "$fake_bd" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "${1:-}" == "version" ]]; then
  echo "some other tool version 1.0"
  exit 0
fi
SCRIPT
  chmod +x "$fake_bd"

  cleanup_binaries

  assert_file_exists "$fake_bd"
}

function test_cleanup_binaries_handles_no_bd_installed() {
  # No bd binary anywhere — should complete without error
  cleanup_binaries
  assert_same "0" "$STAT_BINARIES"
}

function test_cleanup_binaries_dry_run_preserves_binary() {
  APPLY=0
  local fake_bd="$HOME/.local/bin/bd"
  cat > "$fake_bd" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "${1:-}" == "version" ]]; then
  echo "bd version 1.2.3"
  exit 0
fi
SCRIPT
  chmod +x "$fake_bd"

  cleanup_binaries

  assert_file_exists "$fake_bd"
}

function test_cleanup_binaries_finds_go_bin_bd() {
  local fake_bd="$HOME/go/bin/bd"
  cat > "$fake_bd" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "${1:-}" == "version" ]]; then
  echo "bd version 2.0.0"
  exit 0
fi
SCRIPT
  chmod +x "$fake_bd"

  cleanup_binaries

  assert_file_not_exists "$fake_bd"
  assert_greater_than "0" "$STAT_BINARIES"
}

function test_cleanup_binaries_removes_multiple_bd_binaries() {
  for dir in "$HOME/.local/bin" "$HOME/go/bin"; do
    cat > "$dir/bd" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "${1:-}" == "version" ]]; then
  echo "bd version 1.0"
  exit 0
fi
SCRIPT
    chmod +x "$dir/bd"
  done

  cleanup_binaries

  assert_file_not_exists "$HOME/.local/bin/bd"
  assert_file_not_exists "$HOME/go/bin/bd"
}

function test_cleanup_binaries_finds_bd_on_path() {
  # Put a fake bd on PATH so command -v bd succeeds
  local bin_dir="$TEST_DIR/pathbin"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/bd" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "${1:-}" == "version" ]]; then
  echo "bd version 3.0.0"
  exit 0
fi
SCRIPT
  chmod +x "$bin_dir/bd"

  PATH="$bin_dir:$PATH" cleanup_binaries

  assert_file_not_exists "$bin_dir/bd"
  assert_greater_than "0" "$STAT_BINARIES"
}

function test_cleanup_binaries_skips_bd_that_cannot_execute_version() {
  local fake_bd="$HOME/.local/bin/bd"
  cat > "$fake_bd" <<'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT
  chmod +x "$fake_bd"

  # Avoid $() subshell so coverage tracks
  cleanup_binaries > "$TEST_DIR/output.txt" 2>&1 || true

  assert_file_exists "$fake_bd"
  assert_file_contains "$TEST_DIR/output.txt" "Skipping"
}
