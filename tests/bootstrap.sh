#!/usr/bin/env bash
set -euo pipefail

# Helper: reset all global state to defaults
reset_state() {
  APPLY=0
  SKIP_HOME=0
  SKIP_BINARY=0
  MIGRATE_TK=0
  ROOTS=()
  STAT_REMOVED=0
  STAT_CHANGED=0
  STAT_DAEMONS=0
  STAT_BINARIES=0
  MIGRATE_COUNT=0
  CLEANED_REPOS=()
  CACHE_FILE="/tmp/beads-uninstall-test-repos.txt"
  rm -f "$CACHE_FILE"
}
export -f reset_state
