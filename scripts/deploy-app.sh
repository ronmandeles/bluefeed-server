#!/usr/bin/env bash
# Deploy a new version of the app (step 7 of the guide), as the deploy user.
#
#   ./scripts/deploy-app.sh <server-name> deploy@<server-ip> <app-flake>#<package>
#   e.g. test with the built-in demo app:
#   ./scripts/deploy-app.sh bluefeed-server deploy@192.168.1.50 .#bluefeed-server-demo-app
#
# Steps: build the app, `nix copy` it to the server (unsigned for now; the
# deploy user is trusted, package signing is deferred), point the app's profile at
# it, restart the service. Rolling back = point the profile at the previous one:
#   ssh deploy@<ip> "nix-env -p /nix/var/nix/profiles/app/<app> --rollback && sudo systemctl restart <app>.service"
set -euo pipefail
cd "$(dirname "$0")/.."
USAGE="usage: $0 <server-name> deploy@<server-ip> <flake#package>"
HOST="${1:?$USAGE}"
TARGET="${2:?$USAGE}"
REF="${3:?$USAGE}"
APP=$(nix eval --raw --file "hosts/$HOST/settings.nix" app.name)
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
