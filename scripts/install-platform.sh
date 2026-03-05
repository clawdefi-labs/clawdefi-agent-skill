#!/usr/bin/env bash
# =============================================================================
# ClawDeFi Platform File Installer
#
# First-boot installer for platform-managed files (Categories A + B).
# Downloads manifest from the control plane (authenticated), installs all
# platform files, and writes initial .platform-state.json for conflict tracking.
#
# Called by bootstrap.sh after skill installation.
#
# Required env: CONTROL_PLANE_URL, AGENT_TOKEN
# =============================================================================
set -euo pipefail

CONTROL_PLANE_URL="${CONTROL_PLANE_URL:?CONTROL_PLANE_URL is required}"
AGENT_TOKEN="${AGENT_TOKEN:?AGENT_TOKEN is required}"
AGENT_ID="${AGENT_ID:?AGENT_ID is required}"
PLATFORM_BASE_URL="${CONTROL_PLANE_URL}/internal/platform"
MANIFEST_URL="${PLATFORM_BASE_URL}/manifest.json"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
STATE_FILE="${OPENCLAW_HOME}/.platform-state.json"
VERSION_FILE="${OPENCLAW_HOME}/.installed-platform-version"
LOCK_FILE="${OPENCLAW_HOME}/.platform-update.lock"

# Per-agent keys preserved during openclaw.json merge
AGENT_KEYS=("agent_id" "gateway_url" "control_plane_url" "agent_token" "plugins")

auth_curl() {
  curl -fsSL -H "Authorization: Bearer ${AGENT_TOKEN}" -H "X-Agent-Id: ${AGENT_ID}" "$@"
}

sha256_file() {
  local file_path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file_path" | awk '{print $1}'
  else
    shasum -a 256 "$file_path" | awk '{print $1}'
  fi
}

resolve_target() {
  local target="$1"
  # config/openclaw.json → ~/.openclaw/openclaw.json (strip config/ prefix)
  if [[ "$target" == config/* ]]; then
    echo "${OPENCLAW_HOME}/${target#config/}"
  else
    echo "${OPENCLAW_HOME}/${target}"
  fi
}

merge_openclaw_json() {
  local new_template="$1"
  local target_path="$2"
  local merged_tmp="${tmp_dir}/merged-openclaw.json"

  if [ ! -f "$target_path" ]; then
    # No existing config — just use template as-is
    mv "$new_template" "$target_path"
    return 0
  fi

  # Start with new template, overlay per-agent keys from existing config
  cp "$new_template" "$merged_tmp"
  for key in "${AGENT_KEYS[@]}"; do
    local existing_val
    existing_val="$(jq -r --arg k "$key" '.[$k] // empty' "$target_path")"
    if [ -n "$existing_val" ]; then
      local tmp_merge="${tmp_dir}/merge-step.json"
      jq --arg k "$key" --arg v "$existing_val" '.[$k] = $v' "$merged_tmp" > "$tmp_merge"
      mv "$tmp_merge" "$merged_tmp"
    fi
  done

  # Validate merged JSON
  if ! jq empty "$merged_tmp" 2>/dev/null; then
    echo "ERROR: merged openclaw.json is not valid JSON" >&2
    return 1
  fi

  mv "$merged_tmp" "$target_path"
}

# ── Preflight checks ─────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for platform file management" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required for platform file management" >&2
  exit 1
fi

# ── Acquire lock (non-blocking fail if already held) ─────────
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  echo "Another platform install/update is running; skipping" >&2
  exit 0
fi

mkdir -p "$OPENCLAW_HOME" "${OPENCLAW_HOME}/workspace"

tmp_dir="$(mktemp -d)"
manifest_tmp="${tmp_dir}/manifest.json"
trap 'rm -rf "$tmp_dir"' EXIT

# ── Download manifest ─────────────────────────────────────────
echo "Downloading platform manifest from ${MANIFEST_URL}"
if ! auth_curl "$MANIFEST_URL" -o "$manifest_tmp"; then
  echo "WARNING: failed to download platform manifest; continuing without platform files" >&2
  exit 0
fi

remote_version="$(jq -r '.version' "$manifest_tmp")"
if [ -z "$remote_version" ] || [ "$remote_version" = "null" ]; then
  echo "WARNING: manifest missing version field" >&2
  exit 0
fi

file_count="$(jq '.files | length' "$manifest_tmp")"
echo "Platform manifest v${remote_version}: ${file_count} files"

# ── Initialize state ─────────────────────────────────────────
state_json='{"installed_version":"","installed_at":"","files":{}}'
installed_files=()
skipped_files=()

# ── Process each file ─────────────────────────────────────────
for i in $(seq 0 $(( file_count - 1 ))); do
  file_path="$(jq -r --argjson i "$i" '.files[$i].path' "$manifest_tmp")"
  file_category="$(jq -r --argjson i "$i" '.files[$i].category' "$manifest_tmp")"
  file_target="$(jq -r --argjson i "$i" '.files[$i].target' "$manifest_tmp")"
  file_sha256="$(jq -r --argjson i "$i" '.files[$i].sha256' "$manifest_tmp")"

  # Construct authenticated URL from control plane base + file path
  file_url="${PLATFORM_BASE_URL}/files/${file_path}"
  target_path="$(resolve_target "$file_target")"
  file_tmp="${tmp_dir}/${file_path}"

  echo "  [${file_category}] ${file_path} → ${target_path}"

  # Download file (authenticated)
  if ! auth_curl "$file_url" -o "$file_tmp"; then
    echo "  WARNING: failed to download ${file_path}; skipping" >&2
    skipped_files+=("${file_path}=download_failed")
    continue
  fi

  # Verify checksum
  if [ -n "$file_sha256" ] && [ "$file_sha256" != "null" ]; then
    actual_sha256="$(sha256_file "$file_tmp")"
    if [ "$actual_sha256" != "$file_sha256" ]; then
      echo "  WARNING: checksum mismatch for ${file_path}; skipping" >&2
      skipped_files+=("${file_path}=checksum_mismatch")
      continue
    fi
  fi

  # Ensure target directory exists
  mkdir -p "$(dirname "$target_path")"

  # Handle openclaw.json specially (merge, don't overwrite)
  if [ "$file_path" = "openclaw.json" ]; then
    merge_openclaw_json "$file_tmp" "$target_path"
    installed_files+=("${file_path}=installed")

    actual_installed_sha="$(sha256_file "$target_path")"
    state_json="$(echo "$state_json" | jq --arg p "$file_path" --arg ps "$file_sha256" --arg is "$actual_installed_sha" \
      '.files[$p] = {"platform_sha256": $ps, "installed_sha256": $is, "status": "installed"}')"
    continue
  fi

  # Category A: always overwrite
  # Category B: always install on first boot (no conflict on fresh VM)
  # On first boot, both A and B are simply installed.
  atomic_tmp="${target_path}.tmp.$$"
  cp "$file_tmp" "$atomic_tmp"
  mv "$atomic_tmp" "$target_path"
  installed_files+=("${file_path}=installed")

  actual_installed_sha="$(sha256_file "$target_path")"
  state_json="$(echo "$state_json" | jq --arg p "$file_path" --arg ps "$file_sha256" --arg is "$actual_installed_sha" \
    '.files[$p] = {"platform_sha256": $ps, "installed_sha256": $is, "status": "installed"}')"
done

# ── Write state file ──────────────────────────────────────────
now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
state_json="$(echo "$state_json" | jq --arg v "$remote_version" --arg t "$now" \
  '.installed_version = $v | .installed_at = $t')"

echo "$state_json" | jq . > "${STATE_FILE}.tmp.$$"
mv "${STATE_FILE}.tmp.$$" "$STATE_FILE"

echo "$remote_version" > "$VERSION_FILE"

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "Platform files installed (v${remote_version}):"
for result in "${installed_files[@]}"; do
  echo "  ${result}"
done
if [ ${#skipped_files[@]} -gt 0 ]; then
  echo "Skipped:"
  for result in "${skipped_files[@]}"; do
    echo "  ${result}"
  done
fi
