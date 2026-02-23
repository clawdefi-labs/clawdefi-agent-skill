#!/usr/bin/env bash
# =============================================================================
# Generate skill manifest with real SHA256 checksums.
#
# Reads skill/manifest.json, computes SHA256 for SKILL.md (top-level sha256)
# and each file in files[], rewrites the manifest in place with actual hashes.
#
# Usage:
#   ./scripts/generate-skill-manifest.sh           # update manifest in place
#   ./scripts/generate-skill-manifest.sh --check   # exit 1 if manifest is stale
#
# Run this before committing changes to skill/SKILL.md or skill/scripts/*.js.
# CI should run with --check to enforce freshness.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="${SKILL_ROOT}/manifest.json"

sha256_file() {
  local file_path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file_path" | awk '{print $1}'
  else
    shasum -a 256 "$file_path" | awk '{print $1}'
  fi
}

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: ${MANIFEST} not found" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 1
fi

# Read current manifest
manifest_json="$(cat "$MANIFEST")"
file_count="$(echo "$manifest_json" | jq '.files | length')"

# ── Compute top-level SKILL.md sha256 ──
skill_md="${SKILL_ROOT}/SKILL.md"
if [ ! -f "$skill_md" ]; then
  echo "ERROR: ${skill_md} not found" >&2
  exit 1
fi

skill_sha="$(sha256_file "$skill_md")"
updated_manifest="$(echo "$manifest_json" | jq --arg sha "$skill_sha" '.sha256 = $sha')"

# ── Compute SHA256 for each file in files[] ──
for i in $(seq 0 $(( file_count - 1 ))); do
  file_path="$(echo "$manifest_json" | jq -r --argjson i "$i" '.files[$i].path')"
  source_file="${SKILL_ROOT}/${file_path}"

  if [ ! -f "$source_file" ]; then
    echo "ERROR: ${source_file} not found (referenced in manifest as '${file_path}')" >&2
    exit 1
  fi

  actual_sha="$(sha256_file "$source_file")"
  updated_manifest="$(echo "$updated_manifest" | jq --argjson i "$i" --arg sha "$actual_sha" \
    '.files[$i].sha256 = $sha')"
done

# Format consistently
updated_manifest="$(echo "$updated_manifest" | jq .)"

# ── --check mode: compare without writing ──
if [ "${1:-}" = "--check" ]; then
  current="$(jq . "$MANIFEST")"
  # Compare top-level SKILL.md sha256
  current_skill_sha="$(echo "$current" | jq -r '.sha256')"
  updated_skill_sha="$(echo "$updated_manifest" | jq -r '.sha256')"
  # Compare files[] sha256 values
  current_shas="$(echo "$current" | jq '[.files[].sha256] | sort')"
  updated_shas="$(echo "$updated_manifest" | jq '[.files[].sha256] | sort')"

  stale=0
  if [ "$current_skill_sha" != "$updated_skill_sha" ]; then
    echo "ERROR: SKILL.md checksum is stale." >&2
    echo "  Current:  ${current_skill_sha}" >&2
    echo "  Expected: ${updated_skill_sha}" >&2
    stale=1
  fi

  if [ "$current_shas" != "$updated_shas" ]; then
    echo "ERROR: file checksums are stale." >&2
    echo "" >&2
    echo "Expected:" >&2
    echo "$updated_shas" | jq -r '.[]' | while read -r sha; do echo "  $sha"; done >&2
    echo "Current:" >&2
    echo "$current_shas" | jq -r '.[]' | while read -r sha; do echo "  $sha"; done >&2
    stale=1
  fi

  if [ "$stale" -eq 1 ]; then
    echo "" >&2
    echo "Run: ./scripts/generate-skill-manifest.sh" >&2
    exit 1
  fi

  echo "Skill manifest checksums are up to date."
  exit 0
fi

# ── Write updated manifest ──
echo "$updated_manifest" > "$MANIFEST"
echo "Updated ${MANIFEST}:"
echo "  SKILL.md: ${skill_sha}"
for i in $(seq 0 $(( file_count - 1 ))); do
  file_path="$(echo "$updated_manifest" | jq -r --argjson i "$i" '.files[$i].path')"
  file_sha="$(echo "$updated_manifest" | jq -r --argjson i "$i" '.files[$i].sha256')"
  echo "  ${file_path}: ${file_sha}"
done
