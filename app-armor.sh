#!/bin/bash
cat > /etc/apparmor.d/nix-usersns-allow <<EOF
# /etc/apparmor.d/nix-userns-allow
abi <abi/4.0>,
include <tunables/global>

profile nix-userns-allow /nix/store/*/bin/* flags=(unconfined) {
  userns,
}
EOF

sudo apparmor_parser -r /etc/apparmor.d/nix-userns-allow
