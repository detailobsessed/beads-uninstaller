# beads-uninstaller

A comprehensive uninstall/cleanup script for
[Beads](https://github.com/steveyegge/beads) (`bd`)
that removes **all traces** of the tool from a system —
repositories, home directory, binaries, git hooks,
config files, and more.

Tested end-to-end: `brew install beads` → `bd init` →
run uninstaller → verify zero artifacts remain.
**183 automated tests** ensure every cleanup path works
correctly before touching your system.

## Quick Start

```bash
# Clone
git clone https://github.com/detailobsessed/beads-uninstaller.git
cd beads-uninstaller

# Dry-run (safe — no changes are made)
./beads-uninstaller.sh

# Review the output, then apply
./beads-uninstaller.sh --apply
```

## Features

- **Dry-run by default** — no changes unless you pass `--apply`
- **Scan caching** — dry-run saves scan results;
  subsequent `--apply` reuses them instantly
- **Migrate to tk** — optional `--migrate-tk` flag
  preserves tickets by migrating to
  [tk](https://github.com/wedow/ticket) before cleanup
- **Colorized output** — clear visual feedback with
  section headers and action indicators
- **Safe file handling** — only removes files that are
  actually beads-related (e.g. `.aider.conf.yml` is
  checked for beads content before removal)
- **Backup restoration** — restores original git hook
  backups when removing beads hooks
- **Detailed summary** — shows breakdown of files
  removed, files changed, daemons stopped, and
  binaries removed

## What It Cleans Up

### Per-Repository

| Target | Details |
| ------ | ------- |
| **Daemon** | Stops any running `bd` daemon process |
| **Directories** | Removes `.beads/` and `.beads-hooks/` |
| **AGENTS.md** | Strips beads sections; removes if fully generated |
| **AI tool configs** | Cleans `.claude/settings.local.json`, `.gemini/…` |
| **Cursor** | Removes `.cursor/rules/beads.mdc` |
| **Aider** | Removes `.aider/BEADS.md`; checks content first |
| **Git hooks** | Removes beads hooks, restores backups if available |
| **`.gitattributes`** | Strips `merge=beads` and beads comments |
| **`.git/info/exclude`** | Removes beads-related entries |
| **`.git/config`** | Removes `core.hooksPath`, `merge.beads.*`, `beads.*` |
| **Worktrees** | Removes `beads-worktrees` directory from git common dir |

### Home Directory

- `~/.beads/` and `~/.config/bd/`
- Beads hooks from `~/.claude/settings.json` and `~/.gemini/settings.json`
- Beads entries from global gitignore (`~/.gitignore_global` or `~/.config/git/ignore`)
- Global git config: `merge.beads.*`, `beads.*`,
  and `core.hooksPath` (if pointing to beads)
- `~/.beads-planning/` (only if it contains a `.beads` subdirectory)

### Binaries

- `bd` from `/usr/local/bin`, `/opt/homebrew/bin`, `~/.local/bin`, `~/go/bin`
- `brew uninstall bd` (if installed via Homebrew)
- `npm uninstall -g @beads/bd` (if installed via npm)

## Options

- `--apply` — perform deletions (otherwise dry-run)
- `--migrate-tk` — migrate tickets to
  [tk](https://github.com/wedow/ticket) first
- `--root DIR` — scan a specific directory instead
  of `$HOME` (repeatable)
- `--skip-home` — don't touch home-level files
- `--skip-binary` — don't remove the `bd` binary
- `-h, --help` — show help

## Examples

```bash
# Dry-run: see what would be cleaned
./beads-uninstaller.sh

# Migrate tickets to tk, then clean everything
./beads-uninstaller.sh --migrate-tk --apply

# Clean everything (without migrating)
./beads-uninstaller.sh --apply

# Clean a specific project only
./beads-uninstaller.sh --root ~/myproject --skip-home --skip-binary --apply

# Clean multiple projects
./beads-uninstaller.sh --root ~/project1 --root ~/project2 --apply
```

## Testing

The project uses [bashunit](https://bashunit.typeddevs.com/)
with 200+ tests covering all functions. Coverage is
enabled by default via `.env`.

```bash
# Run all tests (with coverage)
./lib/bashunit tests/

# Coverage report is written to coverage/lcov.info
```

## Troubleshooting

If you still see beads artifacts after running the script:

**Git hooks not removed?**

The uninstaller now detects beads hooks by scanning `.git/hooks/`
for beads signatures, even if no other beads artifacts exist.
If hooks persist, manually check:

```bash
grep -r "bd-shim\|bd-hooks-version" .git/hooks/
```

**Config still in `.git/config`?**

Open `.git/config` and remove these sections:

```ini
[merge "beads"]
    driver = bd merge %A %O %A %B
    name = bd JSONL merge driver
[beads]
    role = maintainer
```

## Known Limitations

- **Shell profile entries** — the script does not modify
  `~/.bashrc`, `~/.zshrc`, or similar. If you added `bd`
  to your `PATH` manually, remove that line yourself.
- **Non-standard hook signatures** — if beads installed
  hooks that don't match known patterns, check with:
  `grep -r beads .git/hooks/`

## Requirements

- **bash** 4.0+
- **ripgrep** (`rg`) — used for fast filesystem scanning
- **python3** — used for JSON/AGENTS.md cleanup
- **git** — for git config and hook cleanup

## License

[MIT](LICENSE)

## Attribution

Original script by [banteg](https://gist.github.com/banteg).
This fork adds colorized output, automatic
[tk](https://github.com/wedow/ticket) migration,
scan caching, detailed summary reporting, full
`beads.*` config cleanup, comprehensive test suite,
and documentation.

Fixes incorporated from community feedback by
[raine](https://github.com/raine) and
[ouachitalabs](https://github.com/ouachitalabs).
