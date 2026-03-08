#!/usr/bin/env bash
# bashunit: no-parallel-tests

function set_up() {
  # shellcheck source=../beads-uninstaller.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/beads-uninstaller.sh"
  reset_state
}

# ── print_summary ────────────────────────────────────────────────────────

function test_print_summary_shows_repos_cleaned() {
  APPLY=1
  CLEANED_REPOS=("/tmp/repo1" "/tmp/repo2")

  local output
  output="$(print_summary)"

  assert_contains "Repos cleaned" "$output"
  assert_contains "/tmp/repo1" "$output"
  assert_contains "/tmp/repo2" "$output"
}

function test_print_summary_shows_breakdown_on_apply() {
  APPLY=1
  STAT_REMOVED=5
  STAT_CHANGED=3
  STAT_DAEMONS=1
  STAT_BINARIES=2

  local output
  output="$(print_summary)"

  assert_contains "5" "$output"
  assert_contains "removed" "$output"
  assert_contains "3" "$output"
  assert_contains "modified" "$output"
  assert_contains "1" "$output"
  assert_contains "daemon" "$output"
  assert_contains "2" "$output"
  assert_contains "binary" "$output"
}

function test_print_summary_shows_beads_is_no_more_on_apply() {
  APPLY=1
  STAT_REMOVED=1

  local output
  output="$(print_summary)"

  assert_contains "beads is no more" "$output"
}

function test_print_summary_shows_dry_run_message() {
  APPLY=0
  STAT_REMOVED=1

  local output
  output="$(print_summary)"

  assert_contains "Dry-run complete" "$output"
  assert_contains "--apply" "$output"
}

function test_print_summary_shows_migrate_tk_hint_in_dry_run() {
  APPLY=0
  MIGRATE_TK=0
  STAT_REMOVED=1

  local output
  output="$(print_summary)"

  assert_contains "--migrate-tk" "$output"
}

function test_print_summary_hides_migrate_tk_hint_when_already_set() {
  APPLY=0
  MIGRATE_TK=1
  STAT_REMOVED=1

  local output
  output="$(print_summary)"

  assert_not_contains "--migrate-tk" "$output"
}

function test_print_summary_shows_migration_count() {
  APPLY=1
  MIGRATE_COUNT=5

  local output
  output="$(print_summary)"

  assert_contains "Migrated" "$output"
  assert_contains "5" "$output"
  assert_contains "ticket" "$output"
}

function test_print_summary_hides_migration_when_zero() {
  APPLY=1
  MIGRATE_COUNT=0
  STAT_REMOVED=1

  local output
  output="$(print_summary)"

  assert_not_contains "Migrated" "$output"
}

function test_print_summary_dry_run_verb() {
  APPLY=0
  STAT_REMOVED=3

  local output
  output="$(print_summary)"

  assert_contains "to remove" "$output"
}

function test_print_summary_no_breakdown_when_zero_stats() {
  APPLY=1
  STAT_REMOVED=0
  STAT_CHANGED=0
  STAT_DAEMONS=0
  STAT_BINARIES=0

  local output
  output="$(print_summary)"

  assert_not_contains "Breakdown" "$output"
}

function test_print_summary_no_repos_when_empty() {
  APPLY=1
  CLEANED_REPOS=()

  local output
  output="$(print_summary)"

  assert_not_contains "Repos cleaned" "$output"
}
