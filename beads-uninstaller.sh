#!/usr/bin/env bash
#
# Beads (bd) uninstall/cleanup script (macOS/Linux).
# Dry-run by default; pass --apply to actually delete/modify files.
#
# Usage:
#   ./uninstall.sh                        # dry-run (scan $HOME)
#   ./uninstall.sh --apply                # perform cleanup
#   ./uninstall.sh --migrate-tk --apply   # migrate to tk, then cleanup
#   ./uninstall.sh --root DIR --apply
#   ./uninstall.sh --skip-home --skip-binary
#

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'  GREEN='\033[0;32m'  YELLOW='\033[0;33m'
  BLUE='\033[0;34m' CYAN='\033[0;36m'   BOLD='\033[1m'
  DIM='\033[2m'     RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' RESET=''
fi

APPLY=0
SKIP_HOME=0
SKIP_BINARY=0
MIGRATE_TK=0
ROOTS=()

# ── Stats ────────────────────────────────────────────────────────────────
STAT_REMOVED=0
STAT_CHANGED=0
STAT_DAEMONS=0
STAT_BINARIES=0
MIGRATE_COUNT=0
CLEANED_REPOS=()

CACHE_FILE="/tmp/beads-uninstall-repos.txt"

usage() {
  cat <<'EOF'
Beads uninstall/cleanup script

Defaults:
  - dry-run (no changes)
  - scan $HOME for .beads and related files

Options:
  --apply         Actually delete/modify files (otherwise dry-run)
  --migrate-tk    Migrate beads tickets to tk (ticket) before uninstalling
  --root DIR      Add a scan root (repeatable). If none, uses $HOME.
  --skip-home     Do not touch home-level files (~/.beads, ~/.config/bd, ~/.claude, ~/.gemini)
  --skip-binary   Do not remove the bd binary or package installs
  -h, --help      Show this help

Examples:
  ./uninstall.sh
  ./uninstall.sh --apply
  ./uninstall.sh --migrate-tk --apply
  ./uninstall.sh --root ~/src --apply
EOF
}

log() {
  printf '%b[beads-uninstall]%b %s\n' "$CYAN" "$RESET" "$*"
}

log_section() {
  printf '\n%b══ %s%b\n' "${BOLD}${BLUE}" "$*" "$RESET"
}

log_action() {
  printf '  %b✓%b %s\n' "$GREEN" "$RESET" "$*"
}

log_skip() {
  printf '  %b· %s%b\n' "$DIM" "$*" "$RESET"
}

warn() {
  printf '%b[beads-uninstall] WARN:%b %s\n' "$YELLOW" "$RESET" "$*" >&2
}

run() {
  if [[ "$APPLY" -eq 1 ]]; then
    log_action "$*"
    "$@"
  else
    log_skip "[dry-run] $*"
  fi
  # Track stats based on command type
  case "$1" in
    kill)      (( STAT_DAEMONS++ )) || true ;;
    git)       (( STAT_CHANGED++ )) || true ;;
    brew|npm)  (( STAT_BINARIES++ )) || true ;;
  esac
}

run_rm() {
  local path="$1"
  if [[ "$APPLY" -eq 1 ]]; then
    if [[ -e "$path" ]]; then
      if [[ -w "$(dirname "$path")" ]]; then
        log_action "rm -rf $path"
        rm -rf "$path"
      else
        if command -v sudo >/dev/null 2>&1; then
          log_action "sudo rm -rf $path"
          sudo rm -rf "$path"
        else
          warn "Need permissions to remove $path (run with sudo)"
          return 0
        fi
      fi
      (( STAT_REMOVED++ )) || true
    fi
  else
    log_skip "[dry-run] rm -rf $path"
    (( STAT_REMOVED++ )) || true
  fi
}

run_mv() {
  local src="$1"
  local dst="$2"
  if [[ "$APPLY" -eq 1 ]]; then
    log_action "mv $src $dst"
    mv "$src" "$dst"
  else
    log_skip "[dry-run] mv $src $dst"
  fi
  (( STAT_CHANGED++ )) || true
}

is_beads_hook() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  grep -Eq 'bd-hooks-version:|bd-shim|bd \(beads\)|bd hooks run' "$file"
}

restore_hook_backup() {
  local hook="$1"
  local restored=0

  if [[ -f "${hook}.old" ]]; then
    if is_beads_hook "${hook}.old"; then
      run_rm "${hook}.old"
    else
      run_mv "${hook}.old" "$hook"
      restored=1
    fi
  fi

  if [[ "$restored" -eq 0 && -f "${hook}.backup" ]]; then
    if is_beads_hook "${hook}.backup"; then
      run_rm "${hook}.backup"
    else
      run_mv "${hook}.backup" "$hook"
      restored=1
    fi
  fi

  if [[ "$restored" -eq 0 ]]; then
    local latest=""
    local backups=()
    shopt -s nullglob
    backups=("${hook}".backup-*)
    shopt -u nullglob
    if [[ "${#backups[@]}" -gt 0 ]]; then
      latest=$(find "${backups[@]}" -maxdepth 0 -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)
      # macOS fallback: find -printf is GNU-only
      if [[ -z "$latest" ]]; then
        latest=$(stat -f '%m %N' "${backups[@]}" 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)
      fi
    fi
    if [[ -n "$latest" ]]; then
      if is_beads_hook "$latest"; then
        run_rm "$latest"
      else
        run_mv "$latest" "$hook"
      fi
    fi
  fi
}

cleanup_hooks_dir() {
  local hooks_dir="$1"
  [[ -d "$hooks_dir" ]] || return 0

  local hook
  for hook in pre-commit post-merge pre-push post-checkout prepare-commit-msg post-commit; do
    local path="$hooks_dir/$hook"
    if [[ -f "$path" ]]; then
      if is_beads_hook "$path"; then
        run_rm "$path"
        restore_hook_backup "$path"
      fi
    fi
    # Also clean any leftover beads backups even if the main hook is gone
    local bak
    for bak in "${path}.old" "${path}.backup" "${path}".backup-*; do
      if [[ -f "$bak" ]] && is_beads_hook "$bak"; then
        run_rm "$bak"
      fi
    done
  done
}

cleanup_gitattributes() {
  local repo="$1"
  local file="$repo/.gitattributes"
  [[ -f "$file" ]] || return 0

  local tmp
  tmp=$(mktemp)
  awk '!/merge=beads/ && !/^#.*[Bb]eads.*JSONL/ && !/^#.*[Bb]d merge/' "$file" > "$tmp"
  if ! cmp -s "$file" "$tmp"; then
    if grep -q '[^[:space:]]' "$tmp" 2>/dev/null; then
      run_mv "$tmp" "$file"
    else
      run_rm "$file"
    fi
  fi
  rm -f "$tmp"
}

cleanup_exclude() {
  local git_dir="$1"
  local file="$git_dir/info/exclude"
  [[ -f "$file" ]] || return 0

  local tmp
  tmp=$(mktemp)
  awk '
    function trim(s){sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s}
    {
      t = trim($0)
      if (t ~ /^#.*[Bb]eads/) next
      if (t == ".beads/") next
      if (t == ".beads/issues.jsonl") next
      if (t == ".claude/settings.local.json") next
      if (t == "**/RECOVERY*.md") next
      if (t == "**/SESSION*.md") next
      print
    }
  ' "$file" > "$tmp"

  if ! cmp -s "$file" "$tmp"; then
    if [[ -s "$tmp" ]]; then
      run_mv "$tmp" "$file"
    else
      run_rm "$file"
    fi
  fi
  rm -f "$tmp"
}

cleanup_agents_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 not found; skipping AGENTS.md cleanup for $file"
    return 0
  fi

  APPLY="$APPLY" python3 - "$file" <<'PY'
import os, re, sys
path = sys.argv[1]
apply = os.environ.get("APPLY") == "1"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

orig = content

begin = "<!-- BEGIN BEADS INTEGRATION -->"
end = "<!-- END BEADS INTEGRATION -->"
if begin in content and end in content:
    pattern = re.compile(r"\n?\s*<!-- BEGIN BEADS INTEGRATION -->.*?<!-- END BEADS INTEGRATION -->\s*\n?", re.S)
    content = re.sub(pattern, "\n", content)

heading = "## Landing the Plane (Session Completion)"
if heading in content:
    pattern = re.compile(r"\n?## Landing the Plane \(Session Completion\)[\s\S]*?(?=\n## |\Z)")
    m = pattern.search(content)
    if m:
        block = m.group(0)
        if "bd sync" in block or "git pull --rebase" in block:
            content = content[:m.start()] + "\n" + content[m.end():]

# Strip Quick Reference section if it contains bd commands
qr_pattern = re.compile(r"\n?## Quick Reference[\s\S]*?(?=\n## |\Z)")
m = qr_pattern.search(content)
if m:
    block = m.group(0)
    bd_cmds = ["bd ready", "bd show", "bd close", "bd sync", "bd update"]
    if sum(1 for c in bd_cmds if c in block) >= 2:
        content = content[:m.start()] + "\n" + content[m.end():]

# Strip lines mentioning bd/beads onboarding
content = re.sub(r"(?m)^.*\bbd\b.*\b(?:beads|issue tracking)\b.*$\n?", "", content)
content = re.sub(r"(?m)^.*\b(?:beads|issue tracking)\b.*\bbd\b.*$\n?", "", content)

# Detect fully beads-generated AGENTS.md (contains bd commands)
beads_markers = ["bd onboard", "bd ready", "bd show", "bd close", "bd sync", "bd update"]
if sum(1 for m in beads_markers if m in content) >= 3:
    content = ""

# If only a heading and whitespace remain, treat as empty
if re.match(r"^\s*#[^#].*\s*$", content.strip()):
    content = ""

content = re.sub(r"\n{3,}", "\n\n", content)
changed = content != orig

if not changed:
    sys.exit(0)

if apply:
    if content.strip() == "":
        os.remove(path)
        print(f"Removed empty AGENTS.md: {path}")
    else:
        mode = os.stat(path).st_mode
        with open(path, "w", encoding="utf-8") as f:
            f.write(content.rstrip() + "\n")
        os.chmod(path, mode)
        print(f"Updated AGENTS.md: {path}")
else:
    print(f"Would update AGENTS.md: {path}")
PY
}

cleanup_settings_json() {
  local file="$1"
  local kind="$2"
  [[ -f "$file" ]] || return 0

  if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 not found; skipping JSON cleanup for $file"
    return 0
  fi

  APPLY="$APPLY" python3 - "$file" "$kind" <<'PY'
import json, os, re, sys

path = sys.argv[1]
kind = sys.argv[2]
apply = os.environ.get("APPLY") == "1"

with open(path, "r", encoding="utf-8") as f:
    try:
        data = json.load(f)
    except Exception as e:
        print(f"Skipping {path}: failed to parse JSON ({e})")
        sys.exit(0)

changed = False

targets = {"bd prime", "bd prime --stealth"}
if kind == "claude":
    events = ["SessionStart", "PreCompact"]
else:
    events = ["SessionStart", "PreCompress"]

hooks = data.get("hooks")
if isinstance(hooks, dict):
    for event in list(events):
        event_hooks = hooks.get(event)
        if not isinstance(event_hooks, list):
            continue
        new_event_hooks = []
        for hook in event_hooks:
            if not isinstance(hook, dict):
                new_event_hooks.append(hook)
                continue
            cmds = hook.get("hooks")
            if not isinstance(cmds, list):
                new_event_hooks.append(hook)
                continue
            new_cmds = []
            removed_any = False
            for cmd in cmds:
                if isinstance(cmd, dict) and cmd.get("command") in targets:
                    removed_any = True
                else:
                    new_cmds.append(cmd)
            if removed_any:
                changed = True
            if new_cmds:
                hook["hooks"] = new_cmds
                new_event_hooks.append(hook)
        if new_event_hooks != event_hooks:
            hooks[event] = new_event_hooks
            changed = True
        if event in hooks and not hooks[event]:
            del hooks[event]
            changed = True
    if not hooks:
        data.pop("hooks", None)

onboard = "Before starting any work, run 'bd onboard' to understand the current project state and available issues."
prompt = data.get("prompt")
if isinstance(prompt, str) and onboard in prompt:
    new_prompt = prompt.replace(onboard, "").strip()
    new_prompt = re.sub(r"\n{3,}", "\n\n", new_prompt).strip()
    if new_prompt:
        data["prompt"] = new_prompt
    else:
        data.pop("prompt", None)
    changed = True

if not changed:
    sys.exit(0)

if apply:
    mode = os.stat(path).st_mode
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=True)
        f.write("\n")
    os.chmod(path, mode)
    print(f"Updated settings: {path}")
else:
    print(f"Would update settings: {path}")
PY
}

rmdir_if_empty() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  if [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    run_rm "$dir"
  fi
}

stop_daemon_pid_file() {
  local pid_file="$1"
  [[ -f "$pid_file" ]] || return 0

  local pid
  pid="$(tr -d '[:space:]' < "$pid_file" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0

  if ps -p "$pid" >/dev/null 2>&1; then
    local cmd
    cmd="$(ps -p "$pid" -o comm= 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$cmd" == *bd* ]]; then
      run kill "$pid"
      if [[ "$APPLY" -eq 1 ]]; then
        sleep 0.2 || true
        if ps -p "$pid" >/dev/null 2>&1; then
          run kill -9 "$pid"
        fi
      fi
    else
      warn "PID $pid from $pid_file does not look like bd; skipping"
    fi
  fi
}

cleanup_repo() {
  local repo="$1"
  [[ -d "$repo" ]] || return 0

  CLEANED_REPOS+=("$repo")
  log_section "Repo: $repo"

  # Stop daemon if running
  stop_daemon_pid_file "$repo/.beads/daemon.pid"

  # Remove project integration files
  cleanup_agents_file "$repo/AGENTS.md"
  cleanup_settings_json "$repo/.claude/settings.local.json" "claude"
  cleanup_settings_json "$repo/.gemini/settings.json" "gemini"

  if [[ -f "$repo/.cursor/rules/beads.mdc" ]]; then
    run_rm "$repo/.cursor/rules/beads.mdc"
  fi
  if [[ -f "$repo/.aider.conf.yml" ]]; then
    if grep -qi 'beads\|bd ' "$repo/.aider.conf.yml" 2>/dev/null; then
      run_rm "$repo/.aider.conf.yml"
    fi
  fi
  if [[ -f "$repo/.aider/BEADS.md" ]]; then
    run_rm "$repo/.aider/BEADS.md"
  fi
  if [[ -f "$repo/.aider/README.md" ]]; then
    if grep -qi 'beads\|bd ' "$repo/.aider/README.md" 2>/dev/null; then
      run_rm "$repo/.aider/README.md"
    fi
  fi
  rmdir_if_empty "$repo/.aider"
  rmdir_if_empty "$repo/.cursor/rules"
  rmdir_if_empty "$repo/.cursor"

  # Git-related cleanup
  if command -v git >/dev/null 2>&1; then
    local git_common_dir=""
    git_common_dir="$(git -C "$repo" rev-parse --git-common-dir 2>/dev/null || true)"
    # Resolve relative paths (e.g. ".git") against the repo root
    if [[ -n "$git_common_dir" && "$git_common_dir" != /* ]]; then
      git_common_dir="$repo/$git_common_dir"
    fi
    if [[ -n "$git_common_dir" ]]; then
      # hooks
      cleanup_hooks_dir "$git_common_dir/hooks"

      # core.hooksPath -> .beads-hooks
      local hooks_path=""
      hooks_path="$(git -C "$repo" config --get core.hooksPath 2>/dev/null || true)"
      if [[ -n "$hooks_path" ]]; then
        local abs_hooks_path="$hooks_path"
        if [[ "$hooks_path" != /* ]]; then
          abs_hooks_path="$repo/$hooks_path"
        fi
        cleanup_hooks_dir "$abs_hooks_path"
        if [[ "$hooks_path" == ".beads-hooks" || "$hooks_path" == */.beads-hooks ]]; then
          run git -C "$repo" config --unset core.hooksPath
        fi
      fi

      # merge driver config
      if git -C "$repo" config --get merge.beads.driver >/dev/null 2>&1; then
        run git -C "$repo" config --unset merge.beads.driver
        run git -C "$repo" config --unset merge.beads.name || true
      fi

      # beads.* config keys (e.g. beads.role, beads.backend)
      local beads_keys
      beads_keys="$(git -C "$repo" config --local --get-regexp '^beads\.' 2>/dev/null | awk '{print $1}' || true)"
      if [[ -n "$beads_keys" ]]; then
        while IFS= read -r key; do
          [[ -n "$key" ]] || continue
          run git -C "$repo" config --unset "$key"
        done <<< "$beads_keys"
      fi

      cleanup_gitattributes "$repo"
      cleanup_exclude "$git_common_dir"

      # sync worktrees
      if [[ -d "$git_common_dir/beads-worktrees" ]]; then
        run_rm "$git_common_dir/beads-worktrees"
      fi
    fi
  fi

  # Remove beads directories
  if [[ -d "$repo/.beads-hooks" ]]; then
    run_rm "$repo/.beads-hooks"
  fi
  if [[ -d "$repo/.beads" ]]; then
    run_rm "$repo/.beads"
  fi
}

cleanup_global_git_config() {
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  # Remove global merge.beads.* config
  if git config --global --get merge.beads.driver >/dev/null 2>&1; then
    run git config --global --unset merge.beads.driver
    run git config --global --unset merge.beads.name || true
  fi

  # Remove global beads.* config keys
  local beads_keys
  beads_keys="$(git config --global --get-regexp '^beads\.' 2>/dev/null | awk '{print $1}' || true)"
  if [[ -n "$beads_keys" ]]; then
    while IFS= read -r key; do
      [[ -n "$key" ]] || continue
      run git config --global --unset "$key"
    done <<< "$beads_keys"
  fi

  # Remove global core.hooksPath if it points to a beads directory
  local global_hooks_path
  global_hooks_path="$(git config --global --get core.hooksPath 2>/dev/null || true)"
  if [[ -n "$global_hooks_path" ]]; then
    if [[ "$global_hooks_path" == ".beads-hooks" || "$global_hooks_path" == */.beads-hooks || "$global_hooks_path" == *beads* ]]; then
      run git config --global --unset core.hooksPath
    fi
  fi
}

cleanup_global_gitignore() {
  local ignore_path=""
  if command -v git >/dev/null 2>&1; then
    ignore_path="$(git config --global core.excludesfile 2>/dev/null || true)"
  fi
  if [[ -n "$ignore_path" ]]; then
    # Expand tilde if present
    # shellcheck disable=SC2088
    if [[ "$ignore_path" == '~/'* ]]; then
      ignore_path="${HOME}/${ignore_path#\~/}"
    elif [[ "$ignore_path" == '~' ]]; then
      ignore_path="$HOME"
    fi
  fi

  # Fallback to common locations if not set or doesn't exist
  if [[ ! -f "$ignore_path" ]]; then
    if [[ -f "$HOME/.gitignore_global" ]]; then
      ignore_path="$HOME/.gitignore_global"
    elif [[ -f "$HOME/.config/git/ignore" ]]; then
      ignore_path="$HOME/.config/git/ignore"
    fi
  fi

  [[ -f "$ignore_path" ]] || return 0

  local tmp
  tmp=$(mktemp)
  awk '
    function trim(s){sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s}
    {
      t = trim($0)
      if (t ~ /Beads stealth mode/) next
      if (t ~ /(^|\/)\.beads\/$/) next
      if (t ~ /(^|\/)\.claude\/settings\.local\.json$/) next
      print
    }
  ' "$ignore_path" > "$tmp"

  if ! cmp -s "$ignore_path" "$tmp"; then
    if [[ -s "$tmp" ]]; then
      run_mv "$tmp" "$ignore_path"
    else
      run_rm "$ignore_path"
    fi
  fi
  rm -f "$tmp"
}

cleanup_home() {
  if [[ "$SKIP_HOME" -eq 1 ]]; then
    return 0
  fi

  log_section "Home directory cleanup"

  cleanup_settings_json "$HOME/.claude/settings.json" "claude"
  cleanup_settings_json "$HOME/.gemini/settings.json" "gemini"
  cleanup_global_git_config
  cleanup_global_gitignore

  if [[ -d "$HOME/.beads" ]]; then
    run_rm "$HOME/.beads"
  fi

  if [[ -d "$HOME/.config/bd" ]]; then
    run_rm "$HOME/.config/bd"
  fi

  # Optional: planning repo (only if it looks like a beads repo)
  if [[ -d "$HOME/.beads-planning/.beads" ]]; then
    run_rm "$HOME/.beads-planning"
  fi
}

cleanup_binaries() {
  if [[ "$SKIP_BINARY" -eq 1 ]]; then
    return 0
  fi

  log_section "Binary cleanup"

  local paths_file
  paths_file=$(mktemp)

  if command -v bd >/dev/null 2>&1; then
    if command -v which >/dev/null 2>&1; then
      which -a bd 2>/dev/null | sed '/^$/d' >> "$paths_file" || true
    else
      command -v bd >> "$paths_file" || true
    fi
  fi

  for p in \
    "/usr/local/bin/bd" \
    "/opt/homebrew/bin/bd" \
    "$HOME/.local/bin/bd" \
    "$HOME/go/bin/bd" \
    ; do
    if [[ -x "$p" ]]; then
      printf '%s\n' "$p" >> "$paths_file"
    fi
  done

  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    if [[ -x "$p" ]]; then
      if "$p" version >/dev/null 2>&1; then
        if "$p" version 2>/dev/null | grep -q "^bd version"; then
          run_rm "$p"
          (( STAT_BINARIES++ )) || true
        else
          warn "Skipping $p (not beads)"
        fi
      else
        warn "Skipping $p (cannot execute)"
      fi
    fi
  done < <(sort -u "$paths_file")

  rm -f "$paths_file"

  # Package managers (best-effort)
  if command -v brew >/dev/null 2>&1; then
    if brew list --formula 2>/dev/null | grep -qx "bd"; then
      run brew uninstall bd
    fi
  fi

  if command -v npm >/dev/null 2>&1; then
    if npm ls -g --depth=0 @beads/bd >/dev/null 2>&1; then
      run npm uninstall -g @beads/bd
    fi
  fi
}

# ── tk (ticket) migration ────────────────────────────────────────────────

ensure_tk_installed() {
  if command -v tk >/dev/null 2>&1; then
    return 0
  fi

  log_section "Installing tk (ticket)"

  if command -v brew >/dev/null 2>&1; then
    log "Installing via Homebrew..."
    brew tap wedow/tools 2>/dev/null
    brew install ticket 2>/dev/null
    if command -v tk >/dev/null 2>&1; then
      log_action "tk installed successfully"
      return 0
    fi
  fi

  warn "Could not auto-install tk. Install it manually:"
  warn "  brew tap wedow/tools && brew install ticket"
  warn "  OR: git clone https://github.com/wedow/ticket.git && ln -s \"\$PWD/ticket/ticket\" ~/.local/bin/tk"
  return 1
}

migrate_repos_to_tk() {
  local roots_file="$1"

  [[ "$MIGRATE_TK" -eq 1 ]] || return 0

  log_section "Migrate beads → tk"

  # Count repos with beads data to migrate
  local repos_with_beads=()
  while IFS= read -r repo; do
    [[ -n "$repo" ]] || continue
    if [[ -f "$repo/.beads/issues.jsonl" ]]; then
      repos_with_beads+=("$repo")
    fi
  done < <(sort -u "$roots_file")

  if [[ "${#repos_with_beads[@]}" -eq 0 ]]; then
    log "No repos with beads ticket data found."
    return 0
  fi

  printf '  Found %b%s%b repo(s) with beads tickets to migrate\n' "$BOLD" "${#repos_with_beads[@]}" "$RESET"

  if [[ "$APPLY" -eq 0 ]]; then
    for repo in "${repos_with_beads[@]}"; do
      log_skip "[dry-run] tk migrate-beads in $repo"
    done
    printf '\n  %bTip:%b Run with %b--migrate-tk --apply%b to migrate and uninstall.\n' "$YELLOW" "$RESET" "$BOLD" "$RESET"
    return 0
  fi

  if ! ensure_tk_installed; then
    warn "Skipping migration (tk not available). Beads data will still be removed."
    return 0
  fi

  for repo in "${repos_with_beads[@]}"; do
    log "Migrating: $repo"
    local output
    if output=$(cd "$repo" && tk migrate-beads 2>&1); then
      local count
      count=$(printf '%s\n' "$output" | grep -c '^Migrated:' || true)
      log_action "Migrated $count ticket(s) in $(basename "$repo")"
      (( MIGRATE_COUNT += count )) || true
    else
      warn "Migration failed for $repo: $output"
    fi
  done
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply)
        APPLY=1
        ;;
      --root)
        shift
        [[ $# -gt 0 ]] || { warn "--root requires a directory"; exit 1; }
        ROOTS+=("$1")
        ;;
      --migrate-tk)
        MIGRATE_TK=1
        ;;
      --skip-home)
        SKIP_HOME=1
        ;;
      --skip-binary)
        SKIP_BINARY=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        warn "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

add_repo_root() {
  local path="$1"
  local dir="$path"
  if [[ -f "$path" ]]; then
    dir="$(dirname "$path")"
  fi

  local root=""

  # Special handling for paths inside .git/ since git commands don't work there
  case "$path" in
    */.git/hooks/*|*/.git/hooks)
      # Extract repo root by removing /.git/hooks and everything after
      root="${path%%/.git/hooks*}"
      ;;
    */.beads|*/.beads-hooks)
      root="$(dirname "$path")"
      ;;
    *)
      if command -v git >/dev/null 2>&1; then
        root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
      fi
      if [[ -z "$root" ]]; then
        root="$dir"
      fi
      ;;
  esac

  printf '%s\n' "$root"
}

scan_roots() {
  local roots_file="$1"

  local root abs_root
  for root in "${ROOTS[@]}"; do
    [[ -d "$root" ]] || continue
    abs_root="$(cd "$root" && pwd)"
    log "Scanning: $root"

    # rg globs are matched relative to the search dir, so we cd into it
    (
      cd "$abs_root" || exit

      { rg --files --hidden --no-ignore --null -g '!.git/**' -g '.beads/**' . 2>/dev/null || true; } | while IFS= read -r -d '' file; do
        local full="$abs_root/${file#./}"
        case "$full" in
          "$HOME/.beads"/*)
            continue
            ;;
        esac
        add_repo_root "$full" >> "$roots_file"
      done

      { rg --files --hidden --no-ignore --null -g '!.git/**' -g '.beads-hooks/**' . 2>/dev/null || true; } | while IFS= read -r -d '' file; do
        add_repo_root "$abs_root/${file#./}" >> "$roots_file"
      done

      { rg --files --hidden --no-ignore --null -g '!.git/**' \
        -g '.aider.conf.yml' \
        -g '.cursor/rules/beads.mdc' \
        -g '.aider/BEADS.md' \
        -g '.aider/README.md' \
        -g '.claude/settings.local.json' \
        -g '.gemini/settings.json' \
        . 2>/dev/null || true; } | while IFS= read -r -d '' file; do
          add_repo_root "$abs_root/${file#./}" >> "$roots_file"
        done

      # AGENTS.md that actually contains beads instructions
      { rg -l --hidden --no-ignore --null -g '!.git/**' -g 'AGENTS.md' \
        -e 'Landing the Plane \(Session Completion\)' \
        -e 'BEGIN BEADS INTEGRATION' \
        . 2>/dev/null || true; } | while IFS= read -r -d '' file; do
          add_repo_root "$abs_root/${file#./}" >> "$roots_file"
        done

      # Git hooks containing beads signatures
      # Search for hooks with bd-shim, bd-hooks-version, or "bd (beads)" markers
      { rg -l --hidden --no-ignore --null -g '.git/hooks/*' \
        -e 'bd-shim' \
        -e 'bd-hooks-version:' \
        -e 'bd \(beads\)' \
        -e 'bd hooks run' \
        . 2>/dev/null || true; } | while IFS= read -r -d '' file; do
          add_repo_root "$abs_root/${file#./}" >> "$roots_file"
        done
    )
  done
}

print_summary() {
  local verb="removed"
  [[ "$APPLY" -eq 1 ]] || verb="to remove"

  printf '\n%b── Summary ──────────────────────────────────────────%b\n' "${BOLD}${CYAN}" "$RESET"

  # Project list
  if [[ "${#CLEANED_REPOS[@]}" -gt 0 ]]; then
    printf '  %bRepos cleaned:%b\n' "$BOLD" "$RESET"
    for repo in "${CLEANED_REPOS[@]}"; do
      printf '    %b├─%b %s\n' "$DIM" "$RESET" "$repo"
    done
  fi

  # Migration stats
  if [[ "$MIGRATE_COUNT" -gt 0 ]]; then
    printf '  %b✓%b Migrated %b%s%b ticket(s) to tk\n' "$GREEN" "$RESET" "$BOLD" "$MIGRATE_COUNT" "$RESET"
  fi

  # Breakdown
  local total=$(( STAT_REMOVED + STAT_CHANGED + STAT_DAEMONS + STAT_BINARIES ))
  if [[ "$total" -gt 0 ]]; then
    printf '  %bBreakdown:%b\n' "$BOLD" "$RESET"
    [[ "$STAT_REMOVED" -eq 0 ]] || printf '    %b%s%b file(s)/dir(s) %s\n' "$BOLD" "$STAT_REMOVED" "$RESET" "$verb"
    [[ "$STAT_CHANGED" -eq 0 ]] || printf '    %b%s%b file(s) modified\n' "$BOLD" "$STAT_CHANGED" "$RESET"
    [[ "$STAT_DAEMONS" -eq 0 ]] || printf '    %b%s%b daemon(s) stopped\n' "$BOLD" "$STAT_DAEMONS" "$RESET"
    [[ "$STAT_BINARIES" -eq 0 ]] || printf '    %b%s%b binary/package removal(s)\n' "$BOLD" "$STAT_BINARIES" "$RESET"
  fi

  # Final status
  if [[ "$APPLY" -eq 1 ]]; then
    printf '\n  %b✓ beads is no more.%b\n' "${GREEN}${BOLD}" "$RESET"
  else
    printf '\n  %bDry-run complete.%b\n' "${YELLOW}${BOLD}" "$RESET"
    printf '  Run with %b--apply%b to execute changes.\n' "$BOLD" "$RESET"
    if [[ "$MIGRATE_TK" -eq 0 ]] && [[ "$total" -gt 0 ]]; then
      printf '  Add %b--migrate-tk%b to migrate tickets to tk before uninstalling.\n' "$BOLD" "$RESET"
    fi
  fi
  printf '\n'
}

main() {
  parse_args "$@"

  if [[ "${#ROOTS[@]}" -eq 0 ]]; then
    ROOTS=("$HOME")
  fi

  printf '\n%b  ╔══════════════════════════════════╗%b\n' "${BOLD}${CYAN}" "$RESET"
  printf '%b  ║  Beads (bd) Uninstall Script    ║%b\n' "${BOLD}${CYAN}" "$RESET"
  printf '%b  ╚══════════════════════════════════╝%b\n\n' "${BOLD}${CYAN}" "$RESET"

  if [[ "$APPLY" -eq 1 ]]; then
    printf '  %bMode: APPLY%b ─ changes will be made\n' "${RED}${BOLD}" "$RESET"
  else
    printf '  %bMode: DRY-RUN%b ─ no changes will be made\n' "${GREEN}${BOLD}" "$RESET"
  fi
  printf '  %bRoots:%b\n' "$BOLD" "$RESET"
  for r in "${ROOTS[@]}"; do
    printf '    %b├─%b %s\n' "$DIM" "$RESET" "$r"
  done

  # Scan or reuse cache
  local roots_file
  roots_file=$(mktemp)

  if [[ "$APPLY" -eq 1 ]] && [[ -f "$CACHE_FILE" ]] && [[ -s "$CACHE_FILE" ]]; then
    log "Using cached scan from previous dry-run ($CACHE_FILE)"
    cp "$CACHE_FILE" "$roots_file"
  else
    log "Scanning for beads traces (this may take a while on large trees)..."
    scan_roots "$roots_file"
  fi

  # Save cache on dry-run for next --apply to reuse
  if [[ "$APPLY" -eq 0 ]]; then
    sort -u "$roots_file" > "$CACHE_FILE"
    log "Saved scan results to $CACHE_FILE"
  fi

  # Migrate to tk before cleanup (if requested)
  migrate_repos_to_tk "$roots_file"

  # Clean each detected repo
  while IFS= read -r repo; do
    [[ -n "$repo" ]] || continue
    cleanup_repo "$repo"
  done < <(sort -u "$roots_file")

  rm -f "$roots_file"

  cleanup_home
  cleanup_binaries

  # Remove cache after successful apply
  if [[ "$APPLY" -eq 1 ]] && [[ -f "$CACHE_FILE" ]]; then
    rm -f "$CACHE_FILE"
  fi

  print_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
