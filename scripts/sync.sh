#!/usr/bin/env bash
# Pull latest, export local Cursor config into the repo, commit if needed, push.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "error: not a git repository: ${REPO_ROOT}" >&2
  exit 1
fi

echo "git pull"
git pull --ff-only 2>/dev/null || git pull

echo "export"
"${SCRIPT_DIR}/export.sh"

paths_to_stage=(
  "cursor/settings.json"
  "cursor/keybindings.json"
  "cursor/snippets"
  "extensions.txt"
)

git add -- "${paths_to_stage[@]}" 2>/dev/null || true

if git diff --staged --quiet; then
  echo "No staged changes; skipping commit and push."
  exit 0
fi

ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
git commit -m "chore(sync): cursor settings ${ts}"

echo "git push"
git push

echo "Sync complete."
