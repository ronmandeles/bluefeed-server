#!/usr/bin/env bash
# Installation on the physical server (Ilya), from a laptop on the same LAN.
#
# Before running:
#   1. Boot the server from a NixOS installer USB stick
#      (https://nixos.org/download, "Minimal ISO image").
#   2. On the server's screen run:  sudo passwd root   (temporary password)
#      and:  ip a   (note the IP address)   and:  lsblk   (check the disk name
#      matches "disk" in settings.nix).
#
#   ./scripts/install.sh 192.168.1.50
#
# What it does: connects to the installer, ERASES the disk from settings.nix,
# partitions it (disk.nix), detects the hardware into hardware-configuration.nix,
# installs NixOS with our configuration, and reboots. After the reboot the
# temporary root password is gone; log in with:  ssh <admin-user>@<ip>
#
# On a Mac laptop add BUILD_ON_SERVER=1 (builds on the server instead of the Mac):
#   BUILD_ON_SERVER=1 ./scripts/install.sh 192.168.1.50
set -euo pipefail
cd "$(dirname "$0")/.."
IP="${1:?usage: $0 <server-ip>}"
EXTRA=()
[ "${BUILD_ON_SERVER:-0}" = 1 ] && EXTRA+=(--build-on remote)

if grep -q REPLACE_WITH settings.nix; then
  echo "settings.nix still contains placeholder SSH keys; fill them in first." >&2
  exit 1
fi

DISK=$(nix eval --raw --file settings.nix disk)
read -r -p "This ERASES $DISK on $IP. Type 'yes' to continue: " ANSWER
[ "$ANSWER" = yes ] || { echo "Aborted."; exit 1; }

nix run github:nix-community/nixos-anywhere -- \
  --flake .#server \
  --generate-hardware-config nixos-generate-config ./hardware-configuration.nix \
  --target-host "root@$IP" \
  ${EXTRA[@]+"${EXTRA[@]}"}

echo
echo "Done. hardware-configuration.nix was updated: commit it to the repo (git add hardware-configuration.nix && git commit && git push)."
