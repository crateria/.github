#!/usr/bin/env bash
# Sync centralized Rust policy files to all local workspace checkouts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="${SCRIPT_DIR}/rust-policies"

REPOS=(
  "${SCRIPT_DIR}/../morphball"
  "${SCRIPT_DIR}/../../ubermetroid/trance"
  "${SCRIPT_DIR}/../../ubermetroid/trance-plugins"
  "${SCRIPT_DIR}/../../ubermetroid/packages"
)

for repo in "${REPOS[@]}"; do
  # Resolve to absolute path
  abs_repo="$(cd "$repo" 2>/dev/null && pwd || true)"
  if [[ -n "$abs_repo" && -d "$abs_repo" ]]; then
    echo "Syncing policies to $(basename "$abs_repo") [${abs_repo}]..."
    cp -f "${POLICIES_DIR}/deny.toml" "${abs_repo}/"
    if [[ "$(basename "$abs_repo")" != "packages" ]]; then
      # packages has no clippy.toml or rustfmt.toml currently, but can receive them.
      cp -f "${POLICIES_DIR}/clippy.toml" "${abs_repo}/"
      cp -f "${POLICIES_DIR}/rustfmt.toml" "${abs_repo}/"
    else
      cp -f "${POLICIES_DIR}/rustfmt.toml" "${abs_repo}/"
    fi
  fi
done
echo "All policies synced successfully!"
