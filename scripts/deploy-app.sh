#!/usr/bin/env bash
# Deploy a new version of the app (step 7 of the guide), as the deploy user.
#
#   ./scripts/deploy-app.sh deploy@192.168.1.50 <app-flake>#<package>
#   e.g. test with the built-in demo app:
#   ./scripts/deploy-app.sh deploy@192.168.1.50 .#demo-app
#   or against the test VM:  NIX_SSHOPTS="-p 2222" ./scripts/deploy-app.sh deploy@localhost .#demo-app
#
# Steps: build the app, `nix copy` it to the server (unsigned for now; the
# deploy user is trusted, package signing is deferred), point the app's profile at
# it, restart the service. Rolling back = point the profile at the previous one:
#   ssh deploy@<ip> "nix-env -p /nix/var/nix/profiles/app/<app> --rollback && sudo systemctl restart <app>.service"
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${1:?usage: $0 deploy@<server-ip> <flake#package>}"
REF="${2:?usage: $0 deploy@<server-ip> <flake#package>}"
APP=$(nix eval --raw --file settings.nix app.name)
SSH_PORT_OPT=()
[ -n "${NIX_SSHOPTS:-}" ] && read -r -a SSH_PORT_OPT <<< "$NIX_SSHOPTS"

if [ "$(uname -s)" = Linux ]; then
  OUT=$(nix build --no-link --print-out-paths "$REF")
  nix copy --no-check-sigs --to "ssh-ng://$TARGET" "$OUT"
else
  # Mac: build directly on the server.
  OUT=$(nix build --no-link --print-out-paths --eval-store auto --store "ssh-ng://$TARGET" "$REF")
fi

ssh ${SSH_PORT_OPT[@]+"${SSH_PORT_OPT[@]}"} "$TARGET" \
  "nix-env -p /nix/var/nix/profiles/app/$APP --set $OUT && sudo systemctl restart $APP.service"
echo "Deployed $OUT"
