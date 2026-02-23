#!/usr/bin/env bash
# =============================================================================
# Generate platform manifest with real SHA256 checksums.
#
# Reads skill/platform/manifest.json, computes SHA256 for each referenced file,
# rewrites the manifest in place with actual hashes and current timestamp.
#
# Usage:
#   ./scripts/generate-platform-manifest.sh           # update manifest in place
#   ./scripts/generate-platform-manifest.sh --check   # exit 1 if manifest is stale
#
# Run this before committing changes to skill/platform/*.
# CI should run with --check to enforce freshness.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLATFORM_DIR="${SKILL_ROOT}/platform"
MANIFEST="${PLATFORM_DIR}/manifest.json"

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

# Compute SHA256 for each file and update manifest
updated_manifest="$manifest_json"
for i in $(seq 0 $(( file_count - 1 ))); do
  file_path="$(echo "$manifest_json" | jq -r --argjson i "$i" '.files[$i].path')"
  source_file="${PLATFORM_DIR}/${file_path}"

  if [ ! -f "$source_file" ]; then
    echo "ERROR: ${source_file} not found (referenced in manifest as '${file_path}')" >&2
    exit 1
  fi

  actual_sha="$(sha256_file "$source_file")"
  updated_manifest="$(echo "$updated_manifest" | jq --argjson i "$i" --arg sha "$actual_sha" \
    '.files[$i].sha256 = $sha')"
done

# Update published_at timestamp
updated_manifest="$(echo "$updated_manifest" | jq --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  '.published_at = $ts')"

# Format consistently
updated_manifest="$(echo "$updated_manifest" | jq .)"

# --check mode: compare without writing
if [ "${1:-}" = "--check" ]; then
  current="$(jq . "$MANIFEST")"
  # Compare ignoring published_at (only check sha256 values)
  current_shas="$(echo "$current" | jq '[.files[].sha256] | sort')"
  updated_shas="$(echo "$updated_manifest" | jq '[.files[].sha256] | sort')"

  if [ "$current_shas" != "$updated_shas" ]; then
    echo "ERROR: manifest checksums are stale. Run: ./scripts/generate-platform-manifest.sh" >&2
    echo "" >&2
    echo "Expected:" >&2
    echo "$updated_shas" | jq -r '.[]' | while read -r sha; do echo "  $sha"; done >&2
    echo "Current:" >&2
    echo "$current_shas" | jq -r '.[]' | while read -r sha; do echo "  $sha"; done >&2
    exit 1
  fi

  echo "Manifest checksums are up to date."
  exit 0
fi

# Write updated manifest
echo "$updated_manifest" > "$MANIFEST"
echo "Updated ${MANIFEST}:"
for i in $(seq 0 $(( file_count - 1 ))); do
  file_path="$(echo "$updated_manifest" | jq -r --argjson i "$i" '.files[$i].path')"
  file_sha="$(echo "$updated_manifest" | jq -r --argjson i "$i" '.files[$i].sha256')"
  echo "  ${file_path}: ${file_sha}"
done
