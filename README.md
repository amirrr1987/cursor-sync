# cursor-sync

Git-backed **dotfiles** for [Cursor](https://cursor.com): `settings.json`, `keybindings.json`, `snippets/`, and extension IDs live in this repo so you can recreate the same editor setup on any machine with one install step.

## What is in this repo

| Path | Purpose |
|------|---------|
| `cursor/settings.json` | Editor and workspace settings |
| `cursor/keybindings.json` | Keybindings |
| `cursor/snippets/` | User snippets |
| `extensions.txt` | Extension IDs, one per line (from `cursor --list-extensions`) |
| `scripts/export.sh` | Copy local Cursor `User` data into `cursor/` and refresh `extensions.txt` |
| `scripts/install.sh` | Restore settings into Cursor’s `User` folder and install extensions |
| `scripts/sync.sh` | `git pull` → export → commit **only if something changed** → `git push` |

## Why Git dotfiles instead of Cursor’s built-in sync?

- **You own the history**: every change is a normal Git commit; diffs, branches, and rollbacks are straightforward.
- **Deterministic restores**: `install.sh` reapplies known files and extension IDs; no opaque cloud merge surprises.
- **Works offline**: clone once; no dependency on a vendor sync service being up.
- **Auditable**: review what changed before you merge or push, same as application code.

Built-in sync is convenient, but a repo gives you reproducibility, review, and tooling you already use for the rest of your environment.

## Requirements

- [Cursor](https://cursor.com) installed (so the `User` config directory exists after first launch).
- The **`cursor` shell command** on your `PATH` for extension export/install (`cursor --list-extensions`, `cursor --install-extension`). If the CLI is missing, fix that in Cursor’s documentation / PATH before relying on extension automation.
- **Bash** to run the scripts (Git Bash on Windows, or bash on macOS/Linux).

## First-time setup on a new machine

```bash
git clone https://github.com/amirrr1987/cursor-sync.git
cd cursor-sync
chmod +x scripts/*.sh   # macOS / Linux only
./scripts/install.sh
```

Then restart Cursor so it reloads `settings.json` and keybindings.

### How `install.sh` applies files (cross-platform)

| OS | Method | Why |
|----|--------|-----|
| **macOS / Linux** | **Symlinks** from Cursor’s `User` folder into this repo’s `cursor/` | One canonical copy; edits in Cursor update repo files directly. |
| **Windows (Git Bash)** | **Copies** into `%APPDATA%\Cursor\User` | Avoids symlink privilege / policy issues; re-run `install.sh` or `export.sh` after you change settings locally. |

The script is **idempotent**: safe to run multiple times; it replaces links/copies in a controlled way without touching unrelated Cursor files.

## Export your current machine into the repo

From the repo root:

```bash
./scripts/export.sh
```

This detects the OS, resolves the Cursor `User` directory, copies `settings.json`, `keybindings.json`, and the `snippets/` tree into `cursor/`, and overwrites `extensions.txt` with `cursor --list-extensions`.

Commit the result when you are happy with the diff:

```bash
git status
git add cursor extensions.txt
git commit -m "chore: update cursor config"
```

## Sync workflow (pull → export → commit if needed → push)

Use this on a machine where you edit settings and want the repo to stay the source of truth:

```bash
./scripts/sync.sh
```

Behavior:

1. `git pull` (tries `--ff-only` first, then a normal pull).
2. Runs `export.sh` (local Cursor → repo files).
3. Stages **only** `cursor/settings.json`, `cursor/keybindings.json`, `cursor/snippets/`, and `extensions.txt`.
4. **Commits only if** there is a staged diff (no empty commits).
5. `git push`.

There is no post-commit hook that calls `sync.sh` again, so you do not get push/commit loops.

## Extension list format

`extensions.txt` is plain text: one extension id per line (for example `ms-python.python`). Lines starting with `#` are ignored by `install.sh`. Running `export.sh` replaces the file with the CLI output (comment lines will not survive export; that keeps the list machine-generated and consistent).

## Cursor `User` directory reference

| OS | Path |
|----|------|
| Windows | `%APPDATA%\Cursor\User` |
| macOS | `~/Library/Application Support/Cursor/User` |
| Linux | `~/.config/Cursor/User` |

## Design principles

- **Cross-platform**: Windows / macOS / Linux paths and behaviors are handled explicitly.
- **No VS Code dependency**: scripts target Cursor paths and the `cursor` CLI only.
- **Deterministic**: known files + extension list; same clone + `install.sh` → same baseline.
- **Minimal manual setup**: clone and one install script for the editor side.
- **Safe overwrites**: only the tracked paths are linked or copied; `sync.sh` only stages those paths.
