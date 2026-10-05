#!/bin/bash
echo "Upgrading flake.lock"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
nix --extra-experimental-features "nix-command flakes" flake update --flake "$SCRIPT_DIR"
echo "You can now run ./update.sh"
