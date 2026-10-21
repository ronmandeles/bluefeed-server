#!/usr/bin/env bash
# Install NixOS on a server, from a laptop on the same LAN.
#
# Before running:
#   1. Fill in hosts/<server-name>/settings.nix (see README).
#   2. Boot the server from a NixOS installer USB stick
#      (https://nixos.org/download, "Minimal ISO image").
#   3. On the server's screen run:  sudo passwd root   (temporary password)
#      and:  ip a   (note the IP address).
#
#   ./scripts/install.sh bluefeed-server 192.168.1.50
#
# What it does: connects to the installer, ERASES the disk from settings.nix,
# partitions it (modules/disk.nix), detects the hardware into
# hosts/<server-name>/hardware-configuration.nix, installs NixOS with our
# configuration, and reboots. After the reboot the temporary root password is
# gone; log in with:  ssh <admin-user>@<ip>
#
# On a Mac laptop add BUILD_ON_SERVER=1 (builds on the server instead of the Mac):
#   BUILD_ON_SERVER=1 ./scripts/install.sh bluefeed-server 192.168.1.50
set -euo pipefail
cd "$(dirname "$0")/.."
HOST="${1:?usage: $0 <server-name> <server-ip>}"
IP="${2:?usage: $0 <server-name> <server-ip>}"
DIR="hosts/$HOST"
EXTRA=()
[ "${BUILD_ON_SERVER:-0}" = 1 ] && EXTRA+=(--build-on remote)

[ -f "$DIR/settings.nix" ] || { echo "No $DIR/settings.nix" >&2; exit 1; }
if grep -q REPLACE_WITH "$DIR/settings.nix"; then
  echo "$DIR/settings.nix still contains placeholder SSH keys; fill them in first." >&2
  exit 1
fi

DISK=$(nix eval --raw --file "$DIR/settings.nix" disk)
read -r -p "This ERASES $DISK on $IP. Type 'yes' to continue: " ANSWER
[ "$ANSWER" = yes ] || { echo "Aborted."; exit 1; }

nix run github:nix-community/nixos-anywhere -- \
  --flake ".#$HOST" \
  --generate-hardware-config nixos-generate-config "./$DIR/hardware-configuration.nix" \
  --target-host "root@$IP" \
  ${EXTRA[@]+"${EXTRA[@]}"}

echo
echo "Done. Save the detected hardware and the pinned versions in the repo:"
echo "  git add $DIR/settings.nix $DIR/hardware-configuration.nix flake.lock && git commit -m 'Install $HOST' && git push"
