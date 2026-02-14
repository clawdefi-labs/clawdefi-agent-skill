#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="${SKILL_NAME:-clawdefi-agent}"
MANIFEST_URL="${MANIFEST_URL:-https://skills.clawdefi.ai/${SKILL_NAME}/manifest.json}"
TARGET_ROOT="${TARGET_ROOT:-$HOME/.openclaw/skills}"
TARGET_DIR="${TARGET_ROOT}/${SKILL_NAME}"
TARGET_FILE="${TARGET_DIR}/SKILL.md"
SCRIPT_REL_PATH="scripts/create-wallet.js"
TARGET_SCRIPT="${TARGET_DIR}/${SCRIPT_REL_PATH}"

hash_file() {
  local file_path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file_path" | awk '{print $1}'
  else
    shasum -a 256 "$file_path" | awk '{print $1}'
  fi
}

backup_if_exists() {
  local file_path="$1"
  if [ -f "$file_path" ]; then
    cp "$file_path" "${file_path}.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

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

actual_sha256="$(hash_file "$skill_tmp")"

if [ "$actual_sha256" != "$remote_sha256" ]; then
  echo "Checksum mismatch for downloaded SKILL.md" >&2
  exit 1
fi

script_fetched=0
script_changed=0
downloaded_script_sha256=""
if curl -fsSL "$remote_script_url" -o "$script_tmp"; then
  script_fetched=1
  downloaded_script_sha256="$(hash_file "$script_tmp")"

  if [ -n "$remote_script_sha256" ]; then
    if [ "$downloaded_script_sha256" != "$remote_script_sha256" ]; then
      echo "Checksum mismatch for downloaded ${SCRIPT_REL_PATH}" >&2
      exit 1
    fi
  else
    echo "Warning: no checksum provided for ${SCRIPT_REL_PATH}; syncing without checksum verification." >&2
  fi
else
  echo "Warning: unable to fetch ${SCRIPT_REL_PATH}; script sync check skipped." >&2
fi

skill_changed=1
if [ -f "$TARGET_FILE" ]; then
  local_sha256="$(hash_file "$TARGET_FILE")"
  if [ "$local_sha256" = "$remote_sha256" ]; then
    skill_changed=0
  fi
fi

if [ "$script_fetched" -eq 1 ]; then
  if [ -f "$TARGET_SCRIPT" ]; then
    local_script_sha256="$(hash_file "$TARGET_SCRIPT")"
    if [ "$local_script_sha256" != "$downloaded_script_sha256" ]; then
      script_changed=1
    fi
  else
    script_changed=1
  fi
fi

if [ "$skill_changed" -eq 0 ] && [ "$script_fetched" -eq 1 ] && [ "$script_changed" -eq 0 ]; then
  echo "${SKILL_NAME} is already up to date (${remote_version})"
  exit 0
fi

if [ "$skill_changed" -eq 1 ]; then
  backup_if_exists "$TARGET_FILE"
  mv "$skill_tmp" "$TARGET_FILE"
  skill_status="updated"
else
  rm -f "$skill_tmp"
  skill_status="unchanged"
fi

echo "$remote_version" > "${TARGET_DIR}/.installed-version"

if [ "$script_fetched" -eq 1 ]; then
  if [ "$script_changed" -eq 1 ]; then
    mkdir -p "${TARGET_DIR}/scripts"
    backup_if_exists "$TARGET_SCRIPT"
    mv "$script_tmp" "$TARGET_SCRIPT"
    chmod +x "$TARGET_SCRIPT"
    script_status="updated"
  else
    script_status="unchanged"
  fi
else
  script_status="check-skipped"
fi

echo "Update result for ${SKILL_NAME} (${remote_version}): SKILL.md=${skill_status}, ${SCRIPT_REL_PATH}=${script_status}"
