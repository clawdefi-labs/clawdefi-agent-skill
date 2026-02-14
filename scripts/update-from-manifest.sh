#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="${SKILL_NAME:-clawdefi-agent}"
MANIFEST_URL="${MANIFEST_URL:-https://skills.clawdefi.ai/${SKILL_NAME}/manifest.json}"
TARGET_ROOT="${TARGET_ROOT:-$HOME/.openclaw/skills}"
TARGET_DIR="${TARGET_ROOT}/${SKILL_NAME}"
TARGET_FILE="${TARGET_DIR}/SKILL.md"
SCRIPT_REL_PATH="scripts/create-wallet.js"
TARGET_SCRIPT="${TARGET_DIR}/${SCRIPT_REL_PATH}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for manifest parsing" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

manifest_tmp="$(mktemp)"
skill_tmp="$(mktemp)"
script_tmp="$(mktemp)"
trap 'rm -f "$manifest_tmp" "$skill_tmp" "$script_tmp"' EXIT

curl -fsSL "$MANIFEST_URL" -o "$manifest_tmp"

remote_version="$(jq -r '.version' "$manifest_tmp")"
remote_skill_url="$(jq -r '.skill_url' "$manifest_tmp")"
remote_sha256="$(jq -r '.sha256' "$manifest_tmp")"
remote_script_url="$(jq -r --arg p "$SCRIPT_REL_PATH" '.files[]? | select(.path == $p) | .url // empty' "$manifest_tmp" | head -n 1)"
remote_script_sha256="$(jq -r --arg p "$SCRIPT_REL_PATH" '.files[]? | select(.path == $p) | .sha256 // empty' "$manifest_tmp" | head -n 1)"

if [ -z "$remote_script_url" ]; then
  remote_script_url="$(dirname "$remote_skill_url")/${SCRIPT_REL_PATH}"
fi

if [ -z "$remote_version" ] || [ "$remote_version" = "null" ] || [ -z "$remote_skill_url" ] || [ "$remote_skill_url" = "null" ] || [ -z "$remote_sha256" ] || [ "$remote_sha256" = "null" ]; then
  echo "Manifest is missing required fields (version, skill_url, sha256)" >&2
  exit 1
fi

curl -fsSL "$remote_skill_url" -o "$skill_tmp"

if command -v sha256sum >/dev/null 2>&1; then
  actual_sha256="$(sha256sum "$skill_tmp" | awk '{print $1}')"
else
  actual_sha256="$(shasum -a 256 "$skill_tmp" | awk '{print $1}')"
fi

if [ "$actual_sha256" != "$remote_sha256" ]; then
  echo "Checksum mismatch for downloaded SKILL.md" >&2
  exit 1
fi

if [ -f "$TARGET_FILE" ]; then
  if command -v sha256sum >/dev/null 2>&1; then
    local_sha256="$(sha256sum "$TARGET_FILE" | awk '{print $1}')"
  else
    local_sha256="$(shasum -a 256 "$TARGET_FILE" | awk '{print $1}')"
  fi

  if [ "$local_sha256" = "$remote_sha256" ]; then
    echo "${SKILL_NAME} is already up to date (${remote_version})"
    exit 0
  fi

  cp "$TARGET_FILE" "${TARGET_FILE}.bak.$(date +%Y%m%d%H%M%S)"
fi

mv "$skill_tmp" "$TARGET_FILE"
echo "$remote_version" > "${TARGET_DIR}/.installed-version"

if curl -fsSL "$remote_script_url" -o "$script_tmp"; then
  if [ -n "$remote_script_sha256" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      actual_script_sha256="$(sha256sum "$script_tmp" | awk '{print $1}')"
    else
      actual_script_sha256="$(shasum -a 256 "$script_tmp" | awk '{print $1}')"
    fi

    if [ "$actual_script_sha256" != "$remote_script_sha256" ]; then
      echo "Checksum mismatch for downloaded ${SCRIPT_REL_PATH}" >&2
      exit 1
    fi
  else
    echo "Warning: no checksum provided for ${SCRIPT_REL_PATH}; syncing without checksum verification." >&2
  fi

  mkdir -p "${TARGET_DIR}/scripts"
  if [ -f "$TARGET_SCRIPT" ]; then
    cp "$TARGET_SCRIPT" "${TARGET_SCRIPT}.bak.$(date +%Y%m%d%H%M%S)"
  fi
  mv "$script_tmp" "$TARGET_SCRIPT"
  chmod +x "$TARGET_SCRIPT"
else
  echo "Warning: unable to fetch ${SCRIPT_REL_PATH}; keeping current local copy." >&2
fi

echo "Updated ${SKILL_NAME} to version ${remote_version}"
