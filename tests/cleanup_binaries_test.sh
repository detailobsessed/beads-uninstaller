#!/usr/bin/env bash

function set_up() {
  reset_state
  APPLY=1
  TEST_DIR=$(mktemp -d)
  REAL_HOME="$HOME"
  export HOME="$TEST_DIR/fakehome"
  mkdir -p "$HOME/.local/bin" "$HOME/go/bin"
}

function tear_down() {
  export HOME="$REAL_HOME"
  rm -rf "$TEST_DIR"
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
