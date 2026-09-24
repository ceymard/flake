#!/usr/bin/bash
export NIXPKGS_ALLOW_UNFREE=1
nix --extra-experimental-features "nix-command flakes" run home-manager/master -- switch --extra-experimental-features "nix-command flakes" --flake ~/nix#u1214055 --impure "$@"

