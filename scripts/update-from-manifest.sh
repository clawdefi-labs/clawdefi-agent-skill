#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="${SKILL_NAME:-alphaclaw-agent}"
MANIFEST_URL="${MANIFEST_URL:-https://skills.alphaclaw.ai/${SKILL_NAME}/manifest.json}"
TARGET_ROOT="${TARGET_ROOT:-$HOME/.openclaw/skills}"
TARGET_DIR="${TARGET_ROOT}/${SKILL_NAME}"
TARGET_FILE="${TARGET_DIR}/SKILL.md"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for manifest parsing" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

manifest_tmp="$(mktemp)"
skill_tmp="$(mktemp)"
trap 'rm -f "$manifest_tmp" "$skill_tmp"' EXIT

curl -fsSL "$MANIFEST_URL" -o "$manifest_tmp"

remote_version="$(jq -r '.version' "$manifest_tmp")"
remote_skill_url="$(jq -r '.skill_url' "$manifest_tmp")"
remote_sha256="$(jq -r '.sha256' "$manifest_tmp")"

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

echo "Updated ${SKILL_NAME} to version ${remote_version}"
