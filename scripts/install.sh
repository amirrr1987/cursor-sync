#!/usr/bin/env bash
# Restore Cursor User settings from this repository (idempotent).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${REPO_ROOT}/cursor"

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

same_symlink_target() {
  local path="$1" target="$2"
  if [[ -L "${path}" ]]; then
    local current
    current="$(readlink "${path}" || true)"
    [[ "${current}" == "${target}" ]]
    return
  fi
  return 1
}

install_unix_symlinks() {
  local user_dir="$1"
  mkdir -p "${user_dir}"

  local s_src="${SRC}/settings.json"
  local k_src="${SRC}/keybindings.json"
  local sn_src="${SRC}/snippets"

  if [[ -f "${s_src}" ]]; then
    if same_symlink_target "${user_dir}/settings.json" "${s_src}"; then
      echo "OK: settings.json already linked"
    else
      rm -f "${user_dir}/settings.json"
      ln -s "${s_src}" "${user_dir}/settings.json"
      echo "Linked settings.json"
    fi
  else
    echo "warning: repo missing ${s_src}" >&2
  fi

  if [[ -f "${k_src}" ]]; then
    if same_symlink_target "${user_dir}/keybindings.json" "${k_src}"; then
      echo "OK: keybindings.json already linked"
    else
      rm -f "${user_dir}/keybindings.json"
      ln -s "${k_src}" "${user_dir}/keybindings.json"
      echo "Linked keybindings.json"
    fi
  else
    echo "warning: repo missing ${k_src}" >&2
  fi

  if [[ -d "${sn_src}" ]]; then
    if [[ -L "${user_dir}/snippets" ]] && same_symlink_target "${user_dir}/snippets" "${sn_src}"; then
      echo "OK: snippets already linked"
    else
      rm -rf "${user_dir}/snippets"
      ln -s "${sn_src}" "${user_dir}/snippets"
      echo "Linked snippets/"
    fi
  else
    echo "warning: repo missing snippets dir ${sn_src}" >&2
  fi
}

install_windows_copies() {
  local user_dir="$1"
  mkdir -p "${user_dir}/snippets"

  if [[ -f "${SRC}/settings.json" ]]; then
    cp -f "${SRC}/settings.json" "${user_dir}/settings.json"
    echo "Copied settings.json"
  fi
  if [[ -f "${SRC}/keybindings.json" ]]; then
    cp -f "${SRC}/keybindings.json" "${user_dir}/keybindings.json"
    echo "Copied keybindings.json"
  fi
  rm -rf "${user_dir}/snippets"
  mkdir -p "${user_dir}/snippets"
  if [[ -d "${SRC}/snippets" ]]; then
    cp -a "${SRC}/snippets/." "${user_dir}/snippets/"
    echo "Copied snippets/"
  fi
}

install_extensions() {
  local ext_file="${REPO_ROOT}/extensions.txt"
  if [[ ! -f "${ext_file}" ]]; then
    echo "warning: extensions.txt not found; skipping extensions" >&2
    return 0
  fi

  if ! grep -vE '^[[:space:]]*(#|$)' "${ext_file}" | grep -q .; then
    echo "No extension IDs in ${ext_file}; skipping extension install step."
    return 0
  fi

  local CLI
  CLI="$(resolve_cursor_cli || true)"
  if [[ -z "${CLI}" ]]; then
    echo "error: 'cursor' CLI not on PATH; cannot install extensions" >&2
    echo "  Install Cursor and ensure the shell command is available, then re-run." >&2
    return 1
  fi

  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" ]] && continue
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    line="${line//$'\r'/}"
    [[ -z "${line}" ]] && continue
    echo "Installing extension: ${line}"
    if ! "${CLI}" --install-extension "${line}" </dev/null; then
      echo "warning: failed to install extension: ${line}" >&2
    fi
  done < "${ext_file}"
}

USER_DIR="$(cursor_user_dir)" || exit 1

if [[ ! -d "${SRC}" ]]; then
  echo "error: missing repo cursor dir: ${SRC}" >&2
  exit 1
fi

if is_windows_shell; then
  echo "Windows detected: using file copies (avoids symlink privilege issues)."
  install_windows_copies "${USER_DIR}"
else
  echo "Unix detected: using symlinks into ${SRC}"
  install_unix_symlinks "${USER_DIR}"
fi

install_extensions

echo "Install complete. Cursor user dir: ${USER_DIR}"
