#!/usr/bin/bash
set -euo pipefail

export NIXPKGS_ALLOW_UNFREE=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE="${SCRIPT_DIR}#u1214055"

NIX=(nix --extra-experimental-features "nix-command flakes")
HM=("${NIX[@]}" run home-manager/master --)

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

# pname -> version from a home-manager generation's home-path.
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
    is_internal_pkg "$pname" && continue
    printf '%s\t%s\n' "$pname" "$version"
  done < <(
    "${NIX[@]}" derivation show "$hp" \
      | jq -r '.derivations | to_entries[0].value.structuredAttrs.chosenOutputs[].paths[0]' \
      | sort -u
  )
}

declare -A OLD_VER NEW_VER
CURRENT="$(readlink -f "${HOME}/.local/state/nix/profiles/home-manager")"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "Active generation: $CURRENT"
echo "Building would-be generation from ${FLAKE} ..."
cd "$WORKDIR"
"${HM[@]}" build --extra-experimental-features "nix-command flakes" \
  --flake "$FLAKE" --impure
NEW="$(readlink -f "$WORKDIR/result")"
echo "New generation:    $NEW"
echo

while IFS=$'\t' read -r pname version; do
  OLD_VER["$pname"]="$version"
done < <(home_path_package_map "$CURRENT")

while IFS=$'\t' read -r pname version; do
  NEW_VER["$pname"]="$version"
done < <(home_path_package_map "$NEW")

echo "=== home.packages diff (profile-accessible, excluding HM internals) ==="

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
