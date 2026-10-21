#!/usr/bin/env bash
# Apply a change in these files to the running server (after installation).
# Builds on the server itself, so it works from Linux or Mac laptops.
#
#   ./scripts/update-server.sh ilya@192.168.1.50
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET="${1:?usage: $0 <admin-user>@<server-ip>}"
nix run nixpkgs#nixos-rebuild -- switch --flake .#server \
  --target-host "$TARGET" --build-host "$TARGET" --sudo
