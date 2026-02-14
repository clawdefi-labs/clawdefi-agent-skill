#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="${SKILL_NAME:-clawdefi-agent}"
SKILL_URL="${SKILL_URL:-https://skills.clawdefi.ai/${SKILL_NAME}/SKILL.md}"
MANIFEST_URL="${MANIFEST_URL:-https://skills.clawdefi.ai/${SKILL_NAME}/manifest.json}"
TARGET_ROOT="${TARGET_ROOT:-$HOME/.openclaw/skills}"
TARGET_DIR="${TARGET_ROOT}/${SKILL_NAME}"
SCRIPT_REL_PATH="scripts/create-wallet.js"
TARGET_SCRIPT="${TARGET_DIR}/${SCRIPT_REL_PATH}"

sha256_file() {
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

mkdir -p "$TARGET_DIR" "$TARGET_DIR/scripts"

tmp_dir="$(mktemp -d)"
manifest_tmp="${tmp_dir}/manifest.json"
skill_tmp="${tmp_dir}/SKILL.md"
script_tmp="${tmp_dir}/create-wallet.js"
trap 'rm -rf "$tmp_dir"' EXIT

manifest_present=0
if curl -fsSL "$MANIFEST_URL" -o "$manifest_tmp"; then
  manifest_present=1
fi

download_skill_url="$SKILL_URL"
expected_skill_sha256=""
download_script_url="$(dirname "$SKILL_URL")/${SCRIPT_REL_PATH}"
expected_script_sha256=""

if [ "$manifest_present" -eq 1 ] && command -v jq >/dev/null 2>&1; then
  manifest_skill_url="$(jq -r '.skill_url // empty' "$manifest_tmp")"
  manifest_skill_sha256="$(jq -r '.sha256 // empty' "$manifest_tmp")"
  manifest_script_url="$(jq -r --arg p "$SCRIPT_REL_PATH" '.files[]? | select(.path == $p) | .url // empty' "$manifest_tmp" | head -n 1)"
  manifest_script_sha256="$(jq -r --arg p "$SCRIPT_REL_PATH" '.files[]? | select(.path == $p) | .sha256 // empty' "$manifest_tmp" | head -n 1)"

  if [ -n "$manifest_skill_url" ]; then
    download_skill_url="$manifest_skill_url"
  fi
  if [ -n "$manifest_skill_sha256" ]; then
    expected_skill_sha256="$manifest_skill_sha256"
  fi
  if [ -n "$manifest_script_url" ]; then
    download_script_url="$manifest_script_url"
  fi
  if [ -n "$manifest_script_sha256" ]; then
    expected_script_sha256="$manifest_script_sha256"
  fi
elif [ "$manifest_present" -eq 1 ]; then
  echo "Warning: manifest downloaded but jq is not installed; skipping manifest metadata/checksum parsing." >&2
fi

curl -fsSL "$download_skill_url" -o "$skill_tmp"

if ! grep -q "^name: ${SKILL_NAME}$" "$skill_tmp"; then
  echo "Downloaded file does not appear to match skill name: ${SKILL_NAME}" >&2
  exit 1
fi

if [ -n "$expected_skill_sha256" ]; then
  actual_skill_sha256="$(sha256_file "$skill_tmp")"
  if [ "$actual_skill_sha256" != "$expected_skill_sha256" ]; then
    echo "Checksum mismatch for downloaded SKILL.md" >&2
    exit 1
  fi
fi

curl -fsSL "$download_script_url" -o "$script_tmp"

if [ -n "$expected_script_sha256" ]; then
  actual_script_sha256="$(sha256_file "$script_tmp")"
  if [ "$actual_script_sha256" != "$expected_script_sha256" ]; then
    echo "Checksum mismatch for downloaded ${SCRIPT_REL_PATH}" >&2
    exit 1
  fi
else
  echo "Warning: no checksum provided for ${SCRIPT_REL_PATH}; syncing without checksum verification." >&2
fi

backup_if_exists "${TARGET_DIR}/SKILL.md"
backup_if_exists "$TARGET_SCRIPT"

mv "$skill_tmp" "${TARGET_DIR}/SKILL.md"
mv "$script_tmp" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"

echo "Installed ${SKILL_NAME} to ${TARGET_DIR}"
echo "Synced files:"
echo "- SKILL.md"
echo "- ${SCRIPT_REL_PATH}"
