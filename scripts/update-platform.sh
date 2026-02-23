#!/usr/bin/env bash
# =============================================================================
# ClawDeFi Platform File Updater
#
# Periodic updater for platform-managed files (Categories A + B).
# Downloads manifest from CDN, applies category-aware update logic:
#   - Category A: always overwrite with latest
#   - Category B: skip if agent has locally modified the file
#
# Run by PlatformUpdater (TypeScript) every ~1 hour with jitter.
# =============================================================================
set -euo pipefail

PLATFORM_URL="${PLATFORM_URL:-https://skills.clawdefi.ai/platform}"
MANIFEST_URL="${PLATFORM_URL}/manifest.json"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
STATE_FILE="${OPENCLAW_HOME}/.platform-state.json"
VERSION_FILE="${OPENCLAW_HOME}/.installed-platform-version"
LOCK_FILE="${OPENCLAW_HOME}/.platform-update.lock"

# Per-agent keys preserved during openclaw.json merge
AGENT_KEYS=("agent_id" "gateway_url" "control_plane_url" "agent_token")

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

resolve_target() {
  local target="$1"
  if [[ "$target" == config/* ]]; then
    echo "${OPENCLAW_HOME}/${target#config/}"
  else
    echo "${OPENCLAW_HOME}/${target}"
  fi
}

merge_openclaw_json() {
  local new_template="$1"
  local target_path="$2"

  if [ ! -f "$target_path" ]; then
    mv "$new_template" "$target_path"
    return 0
  fi

  local merged_tmp="${tmp_dir}/merged-openclaw.json"
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

  if ! jq empty "$merged_tmp" 2>/dev/null; then
    echo "ERROR: merged openclaw.json is not valid JSON" >&2
    return 1
  fi

  backup_if_exists "$target_path"
  mv "$merged_tmp" "$target_path"
}

# ── Preflight checks ─────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for platform file management" >&2
  exit 1
fi

# ── Acquire lock ──────────────────────────────────────────────
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
if ! curl -fsSL "$MANIFEST_URL" -o "$manifest_tmp"; then
  echo "Failed to download platform manifest" >&2
  exit 1
fi

remote_version="$(jq -r '.version' "$manifest_tmp")"
if [ -z "$remote_version" ] || [ "$remote_version" = "null" ]; then
  echo "Manifest missing version field" >&2
  exit 1
fi

# ── Load existing state ──────────────────────────────────────
if [ -f "$STATE_FILE" ]; then
  existing_state="$(cat "$STATE_FILE")"
else
  existing_state='{"installed_version":"","installed_at":"","files":{}}'
fi

installed_version="$(echo "$existing_state" | jq -r '.installed_version // empty')"

file_count="$(jq '.files | length' "$manifest_tmp")"

# ── Process files ─────────────────────────────────────────────
updated_any=0
results=()
new_state="$existing_state"

for i in $(seq 0 $(( file_count - 1 ))); do
  file_path="$(jq -r --argjson i "$i" '.files[$i].path' "$manifest_tmp")"
  file_category="$(jq -r --argjson i "$i" '.files[$i].category' "$manifest_tmp")"
  file_target="$(jq -r --argjson i "$i" '.files[$i].target' "$manifest_tmp")"
  file_url="$(jq -r --argjson i "$i" '.files[$i].url' "$manifest_tmp")"
  file_sha256="$(jq -r --argjson i "$i" '.files[$i].sha256' "$manifest_tmp")"

  target_path="$(resolve_target "$file_target")"
  file_tmp="${tmp_dir}/${file_path}"

  # ── Check if file needs update ──────────────────────────
  if [ -f "$target_path" ]; then
    current_sha="$(sha256_file "$target_path")"

    # Already matches the manifest SHA — no update needed
    if [ -n "$file_sha256" ] && [ "$file_sha256" != "null" ] && [ "$current_sha" = "$file_sha256" ]; then
      results+=("${file_path}=unchanged")
      continue
    fi

    # ── Category B conflict detection ───────────────────
    if [ "$file_category" = "B" ]; then
      # Get the SHA we installed last time
      state_installed_sha="$(echo "$existing_state" | jq -r --arg p "$file_path" '.files[$p].installed_sha256 // empty')"

      if [ -n "$state_installed_sha" ] && [ "$current_sha" != "$state_installed_sha" ]; then
        # On-disk SHA differs from what we installed → agent modified it
        results+=("${file_path}=skipped_agent_modified")

        # Record skip reason in state
        new_state="$(echo "$new_state" | jq --arg p "$file_path" --arg ps "$file_sha256" \
          '.files[$p].status = "skipped_agent_modified" | .files[$p].platform_sha256 = $ps')"
        continue
      fi
    fi
  fi

  # ── Download file ───────────────────────────────────────
  if ! curl -fsSL "$file_url" -o "$file_tmp"; then
    echo "WARNING: failed to download ${file_path}" >&2
    results+=("${file_path}=download_failed")
    continue
  fi

  # ── Verify checksum ─────────────────────────────────────
  if [ -n "$file_sha256" ] && [ "$file_sha256" != "null" ]; then
    actual_sha256="$(sha256_file "$file_tmp")"
    if [ "$actual_sha256" != "$file_sha256" ]; then
      echo "WARNING: checksum mismatch for ${file_path}" >&2
      results+=("${file_path}=checksum_mismatch")
      continue
    fi
  fi

  mkdir -p "$(dirname "$target_path")"

  # ── Handle openclaw.json merge ──────────────────────────
  if [ "$file_path" = "openclaw.json" ]; then
    merge_openclaw_json "$file_tmp" "$target_path"
    updated_any=1
    results+=("${file_path}=updated")

    actual_installed_sha="$(sha256_file "$target_path")"
    new_state="$(echo "$new_state" | jq --arg p "$file_path" --arg ps "$file_sha256" --arg is "$actual_installed_sha" \
      '.files[$p] = {"platform_sha256": $ps, "installed_sha256": $is, "status": "installed"}')"
    continue
  fi

  # ── Atomic write with backup ────────────────────────────
  backup_if_exists "$target_path"
  atomic_tmp="${target_path}.tmp.$$"
  cp "$file_tmp" "$atomic_tmp"
  mv "$atomic_tmp" "$target_path"
  updated_any=1
  results+=("${file_path}=updated")

  actual_installed_sha="$(sha256_file "$target_path")"
  new_state="$(echo "$new_state" | jq --arg p "$file_path" --arg ps "$file_sha256" --arg is "$actual_installed_sha" \
    '.files[$p] = {"platform_sha256": $ps, "installed_sha256": $is, "status": "installed"}')"
done

# ── No changes check ─────────────────────────────────────────
if [ "$updated_any" -eq 0 ]; then
  echo "Platform files already up to date (v${remote_version})"
  exit 0
fi

# ── Write updated state ──────────────────────────────────────
now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
new_state="$(echo "$new_state" | jq --arg v "$remote_version" --arg t "$now" \
  '.installed_version = $v | .installed_at = $t')"

echo "$new_state" | jq . > "${STATE_FILE}.tmp.$$"
mv "${STATE_FILE}.tmp.$$" "$STATE_FILE"

echo "$remote_version" > "$VERSION_FILE"

# ── Output results ────────────────────────────────────────────
echo "Platform update result (v${remote_version}):"
for result in "${results[@]}"; do
  echo "  ${result}"
done
