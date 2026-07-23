#!/usr/bin/env bash
# Sync centralized Rust policy files into sibling product checkouts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="${SCRIPT_DIR}/rust-policies"
ROOT="${CRATERIA_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

REPOS=(
  trance
  trance-plugins
  packages
)

for name in "${REPOS[@]}"; do
  abs_repo="${ROOT}/${name}"
  if [[ ! -d "$abs_repo" ]]; then
    for cand in "${SCRIPT_DIR}/../${name}" "${HOME}/src/crateria/${name}"; do
      if [[ -d "$cand" ]]; then abs_repo="$cand"; break; fi
    done
  fi
  if [[ ! -d "$abs_repo" ]]; then
    echo "skip ${name} (not found under ${ROOT})"
    continue
  fi
  echo "Syncing policies → ${abs_repo}"
  cp -f "${POLICIES_DIR}/deny.toml" "${abs_repo}/"
  cp -f "${POLICIES_DIR}/clippy.toml" "${abs_repo}/" 2>/dev/null || true
  cp -f "${POLICIES_DIR}/rustfmt.toml" "${abs_repo}/"
done
echo "Done."
