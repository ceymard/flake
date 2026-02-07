#!/usr/bin/bash
export NIXPKGS_ALLOW_UNFREE=1
nix run home-manager/master -- switch --flake ~/nix#u1214055 --impure
