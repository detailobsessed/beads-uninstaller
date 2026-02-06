# Beads Uninstall Script

A comprehensive uninstall/cleanup script for [Beads](https://github.com/steveyegge/beads) (`bd`) that removes **all traces** of the tool from a system — repositories, home directory, binaries, git hooks, config files, and more.

## Quick Start

### 1. Clone the repository

```bash
git clone https://gist.github.com/f083720a5a6e15af2ea1bb36040a4003.git beads-uninstall
cd beads-uninstall
```

### 2. Make the script executable

```bash
chmod +x uninstall.sh
```

### 3. Run a dry-run first (safe — no changes are made)

```bash
./uninstall.sh
```

This scans your `$HOME` directory and shows everything that **would** be removed, without touching anything.

### 4. Review the output

Look through the dry-run output. Each item is prefixed with `[dry-run]` so you can see exactly what will happen.

### 5. Apply the cleanup

Once you're satisfied:

```bash
./uninstall.sh --apply
```

### 6. (Optional) Migrate to tk first

If you want to preserve your beads tickets by migrating them to [tk](https://github.com/wedow/ticket) before uninstalling:

```bash
./uninstall.sh --migrate-tk --apply
```

This will automatically install `tk` (via Homebrew if available), run `tk migrate-beads` in each detected repo, and then proceed with the beads cleanup.

### 7. (Optional) Target specific directories

If you only want to clean specific project directories:

```bash
./uninstall.sh --root ~/myproject --skip-home --skip-binary --apply
```

## Features

- **Dry-run by default** — no changes unless you pass `--apply`
- **Migrate to tk** — optional `--migrate-tk` flag preserves tickets by migrating to [tk](https://github.com/wedow/ticket) before cleanup
- **Colorized output** — clear visual feedback with section headers and action indicators
- **Safe file handling** — only removes files that are actually beads-related (e.g. `.aider.conf.yml` is checked for beads content before removal)
- **Backup restoration** — restores original git hook backups when removing beads hooks
- **Summary report** — shows total action count at the end

## What It Cleans Up

### Per-Repository

| Target | Details |
|--------|---------|
| **Daemon** | Stops any running `bd` daemon process |
| **Directories** | Removes `.beads/` and `.beads-hooks/` |
| **AGENTS.md** | Strips beads-injected sections (preserves the rest) |
| **AI tool configs** | Cleans `.claude/settings.local.json`, `.gemini/settings.json` |
| **Cursor** | Removes `.cursor/rules/beads.mdc` |
| **Aider** | Removes `.aider/BEADS.md`; only removes `.aider.conf.yml` and `.aider/README.md` if they contain beads content |
| **Git hooks** | Removes beads hooks, restores backups if available |
| **`.gitattributes`** | Strips `merge=beads` lines |
| **`.git/info/exclude`** | Removes beads-related entries |
| **`.git/config`** | Unsets `core.hooksPath` (if `.beads-hooks`) and removes `merge.beads.*` driver config |
| **Worktrees** | Removes `beads-worktrees` directory from git common dir |

### Home Directory

- `~/.beads/` and `~/.config/bd/`
- Beads hooks from `~/.claude/settings.json` and `~/.gemini/settings.json`
- Beads entries from global gitignore
- `~/.beads-planning/` (only if it contains a `.beads` subdirectory)

### Binaries

- `bd` from `/usr/local/bin`, `/opt/homebrew/bin`, `~/.local/bin`, `~/go/bin`
- `brew uninstall bd` (if installed via Homebrew)
- `npm uninstall -g @beads/bd` (if installed via npm)

## Options

| Flag | Description |
|------|-------------|
| `--apply` | Actually perform deletions (otherwise dry-run) |
| `--migrate-tk` | Migrate beads tickets to [tk](https://github.com/wedow/ticket) before uninstalling |
| `--root DIR` | Scan a specific directory instead of `$HOME` (repeatable) |
| `--skip-home` | Don't touch home-level files |
| `--skip-binary` | Don't remove the `bd` binary |
| `-h, --help` | Show help |

## Examples

```bash
# Dry-run: see what would be cleaned
./uninstall.sh

# Migrate tickets to tk, then clean everything
./uninstall.sh --migrate-tk --apply

# Clean everything (without migrating)
./uninstall.sh --apply

# Clean a specific project only
./uninstall.sh --root ~/myproject --skip-home --skip-binary --apply

# Clean multiple projects
./uninstall.sh --root ~/project1 --root ~/project2 --apply
```

## Troubleshooting

If you still see beads artifacts after running the script, check these manual steps:

**Git hooks not fully removed?**
```bash
rm -rf .git/hooks/
```

**Merge driver still in `.git/config`?**
Open `.git/config` and remove the `[merge "beads"]` section:
```ini
[merge "beads"]
    driver = bd merge %A %O %A %B
    name = bd JSONL merge driver
```

## Known Limitations

The script handles the vast majority of beads artifacts automatically. In rare edge cases you may still need to:

- **Manually remove git hooks** if beads installed hooks that don't match the known signature patterns (`bd-hooks-version`, `bd-shim`, `bd hooks run`). Check with: `grep -r beads .git/hooks/`
- **Check `.git/config`** if beads was configured through a mechanism other than `git config` (e.g. manual editing). The script only removes `merge.beads.*` and `core.hooksPath` entries.
- **Shell profile entries** — the script does not modify `~/.bashrc`, `~/.zshrc`, or similar. If you added `bd` to your `PATH` manually, remove that line yourself.

## Requirements

- **bash** 4.0+
- **ripgrep** (`rg`) — used for fast filesystem scanning
- **python3** — used for JSON/AGENTS.md cleanup
- **git** — for git config and hook cleanup

## Attribution

Original script by [banteg](https://gist.github.com/banteg). This fork adds colorized output, automatic [tk](https://github.com/wedow/ticket) migration, bug fixes (safe `.aider.conf.yml` handling, improved hook cleanup), and documentation improvements.

Fixes incorporated from community feedback by [raine](https://github.com/raine) and [ouachitalabs](https://github.com/ouachitalabs).
