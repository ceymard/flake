#!/usr/bin/bash
set -euo pipefail

export NIXPKGS_ALLOW_UNFREE=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX=(nix --extra-experimental-features "nix-command flakes")

# Pulled in by Home Manager modules, not listed in flake home.packages.
HM_INTERNAL_PKGS=(
  shared-mime-info
  dummy-xdg-mime-dirs1
  dummy-xdg-mime-dirs2
  dummy-fc-dir1
  dummy-fc-dir2
  home-configuration-reference-manpage
  hm-session-vars
  hm-session-vars.sh
  nix-zsh-completions
  man-db
  zsh
  desktop-file-utils
)

is_internal_pkg() {
  local pname="$1"
  local internal
  for internal in "${HM_INTERNAL_PKGS[@]}"; do
    [[ "$pname" == "$internal" ]] && return 0
  done
  return 1
}

# pname -> version from the active home-manager generation (already on disk).
home_path_package_map() {
  local gen="$1"
  local hp pname version
  hp="$(readlink -f "${gen}/home-path")"

  while read -r store_path; do
    [[ -z "$store_path" ]] && continue
    pname="$("${NIX[@]}" eval --raw --expr "
      let base = builtins.baseNameOf \"${store_path}\";
          stripped = builtins.match \"[a-z0-9]{32}-(.*)\" base;
          tail = if stripped == null then base else builtins.elemAt stripped 0;
          parsed = builtins.parseDrvName tail;
      in parsed.name")"
    version="$("${NIX[@]}" eval --raw --expr "
      let base = builtins.baseNameOf \"${store_path}\";
          stripped = builtins.match \"[a-z0-9]{32}-(.*)\" base;
          tail = if stripped == null then base else builtins.elemAt stripped 0;
          parsed = builtins.parseDrvName tail;
      in parsed.version")"
    pname="$(normalize_pkg_key "${pname%-bin}")"
    is_internal_pkg "$pname" && continue
    printf '%s\t%s\n' "$pname" "$version"
  done < <(
    "${NIX[@]}" derivation show "$hp" \
      | jq -r '.derivations | to_entries[0].value.structuredAttrs.chosenOutputs[].paths[0]' \
      | sort -u
  )
}

# pname -> version from flake evaluation only (no build, no profile switch).
flake_package_map() {
  "${NIX[@]}" eval --impure --json --expr "
    let
      flake = builtins.getFlake \"${SCRIPT_DIR}\";
      user = builtins.getEnv \"USER\";
      packages = flake.homeConfigurations.\${user}.config.home.packages;
    in map (p:
      let parsed = builtins.parseDrvName p.name;
      in {
        pname = p.pname or parsed.name;
        version = p.version or parsed.version or \"unknown\";
      }
    ) packages
  " | jq -r '.[] | [.pname, .version] | @tsv' | while IFS=$'\t' read -r pname version; do
    pname="$(normalize_pkg_key "$pname")"
    is_internal_pkg "$pname" && continue
    printf '%s\t%s\n' "$pname" "$version"
  done
}

normalize_pkg_key() {
  local k="$1"
  if [[ "$k" =~ ^python[0-9.]+-(.+)$ ]]; then
    k="${BASH_REMATCH[1]}"
  fi
  case "$k" in
    rustc-wrapper) k="rustc" ;;
  esac
  printf '%s' "$k"
}

normalize_version() {
  local v="$1"
  v="${v%-bin}"
  [[ -z "$v" ]] && v="unknown"
  printf '%s' "$v"
}

declare -A OLD_VER NEW_VER
CURRENT="$(readlink -f "${HOME}/.local/state/nix/profiles/home-manager")"

echo "Active generation: $CURRENT"
echo "Evaluating ${SCRIPT_DIR} (flake + lock, no build) ..."
echo

while IFS=$'\t' read -r pname version; do
  OLD_VER["$pname"]="$(normalize_version "$version")"
done < <(home_path_package_map "$CURRENT")

while IFS=$'\t' read -r pname version; do
  NEW_VER["$pname"]="$(normalize_version "$version")"
done < <(flake_package_map)

echo "=== home.packages diff (active profile vs flake eval) ==="

changed=0
for pname in $(printf '%s\n' "${!OLD_VER[@]}" "${!NEW_VER[@]}" | sort -u); do
  old="${OLD_VER[$pname]-}"
  new="${NEW_VER[$pname]-}"
  if [[ "$old" == "$new" ]]; then
    continue
  fi
  changed=1
  if [[ -z "$old" ]]; then
    printf '%s: ∅ → %s\n' "$pname" "$new"
  elif [[ -z "$new" ]]; then
    printf '%s: %s → ∅\n' "$pname" "$old"
  else
    printf '%s: %s → %s\n' "$pname" "$old" "$new"
  fi
done

if [[ "$changed" -eq 0 ]]; then
  echo "(no changes to your declared packages)"
fi
