#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="${SKILL_NAME:-clawdefi-agent}"
SKILL_URL="${SKILL_URL:-https://skills.clawdefi.ai/${SKILL_NAME}/SKILL.md}"
TARGET_ROOT="${TARGET_ROOT:-$HOME/.openclaw/skills}"
TARGET_DIR="${TARGET_ROOT}/${SKILL_NAME}"

mkdir -p "$TARGET_DIR"

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

curl -fsSL "$SKILL_URL" -o "$tmp_file"

if ! grep -q "^name: ${SKILL_NAME}$" "$tmp_file"; then
  echo "Downloaded file does not appear to match skill name: ${SKILL_NAME}" >&2
  exit 1
fi

if [ -f "${TARGET_DIR}/SKILL.md" ]; then
  cp "${TARGET_DIR}/SKILL.md" "${TARGET_DIR}/SKILL.md.bak.$(date +%Y%m%d%H%M%S)"
fi

mv "$tmp_file" "${TARGET_DIR}/SKILL.md"

echo "Installed ${SKILL_NAME} to ${TARGET_DIR}/SKILL.md"
