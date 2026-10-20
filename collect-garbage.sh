#!/usr/bin/bash
set -euo pipefail

export NIXPKGS_ALLOW_UNFREE=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX=(nix --extra-experimental-features "nix-command flakes")
HM=( "${NIX[@]}" run home-manager/master -- )

# TIMESTAMP is interpreted like GNU date -d (e.g. "-7 days", "2026-01-01").
RETAIN="${1:--7 days}"

echo "Removing home-manager generations older than ${RETAIN} ..."
"${HM[@]}" expire-generations "$RETAIN" --flake "${SCRIPT_DIR}#${USER}"

echo "Collecting garbage ..."
"${NIX[@]}" store gc
