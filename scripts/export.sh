#!/usr/bin/env bash
# Export Cursor User settings into this repository (cursor/, extensions.txt).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST="${REPO_ROOT}/cursor"

is_windows_shell() {
  case "$(uname -s)" in
    CYGWIN* | MINGW* | MSYS*) return 0 ;;
    *) return 1 ;;
  esac
}

cursor_user_dir() {
  if is_windows_shell; then
    if [[ -z "${APPDATA:-}" ]]; then
      echo "error: APPDATA is not set (expected on Windows)" >&2
      return 1
    fi
    printf '%s\n' "${APPDATA}/Cursor/User"
    return 0
  fi

  case "$(uname -s)" in
    Darwin*)
      printf '%s\n' "${HOME}/Library/Application Support/Cursor/User"
      ;;
    Linux*)
      printf '%s\n' "${HOME}/.config/Cursor/User"
      ;;
    *)
      echo "error: unsupported OS: $(uname -s)" >&2
      return 1
      ;;
  esac
}

resolve_cursor_cli() {
  if command -v cursor >/dev/null 2>&1; then
    printf '%s\n' "cursor"
    return 0
  fi
  if command -v cursor.cmd >/dev/null 2>&1; then
    printf '%s\n' "cursor.cmd"
    return 0
  fi
  return 1
}

USER_DIR="$(cursor_user_dir)" || exit 1

if [[ ! -d "${USER_DIR}" ]]; then
  echo "error: Cursor user directory not found: ${USER_DIR}" >&2
  echo "Install Cursor once so it creates this folder, then re-run export." >&2
  exit 1
fi

mkdir -p "${DEST}/snippets"

if [[ -f "${USER_DIR}/settings.json" ]]; then
  cp -f "${USER_DIR}/settings.json" "${DEST}/settings.json"
else
  echo "warning: missing ${USER_DIR}/settings.json (skipped)" >&2
fi

if [[ -f "${USER_DIR}/keybindings.json" ]]; then
  cp -f "${USER_DIR}/keybindings.json" "${DEST}/keybindings.json"
else
  echo "warning: missing ${USER_DIR}/keybindings.json (skipped)" >&2
fi

if [[ -d "${USER_DIR}/snippets" ]]; then
  rm -rf "${DEST}/snippets"
  mkdir -p "${DEST}/snippets"
  cp -a "${USER_DIR}/snippets/." "${DEST}/snippets/"
else
  echo "warning: no snippets directory at ${USER_DIR}/snippets; exporting empty snippets/" >&2
  rm -rf "${DEST}/snippets"
  mkdir -p "${DEST}/snippets"
  : >"${DEST}/snippets/.gitkeep"
fi

CLI="$(resolve_cursor_cli || true)"
if [[ -n "${CLI}" ]]; then
  if "${CLI}" --list-extensions >"${REPO_ROOT}/extensions.txt" 2>/dev/null; then
    echo "Wrote extension list via ${CLI}"
  else
    echo "warning: '${CLI} --list-extensions' failed; extensions.txt not updated" >&2
  fi
else
  echo "warning: 'cursor' CLI not on PATH; extensions.txt not updated" >&2
  echo "  Add Cursor to PATH or run from a shell where 'cursor --list-extensions' works." >&2
fi

echo "Export complete -> ${DEST} and ${REPO_ROOT}/extensions.txt"
