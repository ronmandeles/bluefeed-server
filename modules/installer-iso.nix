# Self-installing USB image for one server (built with: make iso HOST=<name>).
#
# Boot the server from the USB stick (BIOS/UEFI boot menu) and the installer
# starts on its own: it shows the target disk, asks for confirmation, partitions
# the disk, installs the server's configuration from the USB (no network
# needed), saves the detected hardware, and asks to reboot.
#
# The image holds only the server's configuration and public SSH keys; no secrets.
{ lib, pkgs, modulesPath, target, settings, ... }:
let
  host = target.config.networking.hostName;
  system = target.config.system.build.toplevel;
  disko = target.config.system.build.diskoScript;
  disk = target.config.disko.devices.disk.main.device;

  installer = pkgs.writeShellApplication {
    name = "auto-install";
    runtimeInputs = with pkgs; [ util-linux coreutils ncurses nixos-install-tools ];
    text = ''
      clear
      echo "=================================================================="
      echo "  Bluefeed server installer: ${host}"
      echo "=================================================================="
      echo
      echo "Disks in this machine:"
      lsblk -d -o NAME,SIZE,MODEL
      echo
      if [ ! -b "${disk}" ]; then
        echo "ERROR: the disk from settings.nix was not found: ${disk}"
        echo "Fix 'disk' in hosts/${host}/settings.nix, rebuild the image and try again."
        echo "Disk names:"; ls -l /dev/disk/by-id/ || true
        exec bash -l
      fi
      echo "Target disk: ${disk} ($(lsblk -dn -o SIZE "${disk}"))"
      echo
      echo "ALL DATA ON THIS DISK WILL BE ERASED."
      read -r -p "Type 'yes' to install, anything else to cancel: " answer
      if [ "$answer" != yes ]; then
        echo "Cancelled. Nothing was changed."; exec bash -l
      fi

      echo; echo ">>> 1/3 Partitioning and formatting ${disk}"
      ${disko} --yes-wipe-all-disks

      echo; echo ">>> 2/3 Installing NixOS (${host}) from the USB stick"
      nixos-install --system ${system} --no-root-passwd --no-channel-copy

      echo; echo ">>> 3/3 Saving the detected hardware"
      mkdir -p /mnt/etc/nixos
      nixos-generate-config --no-filesystems --show-hardware-config --root /mnt \
        > /mnt/etc/nixos/hardware-configuration.nix

      echo
      echo "=================================================================="
      echo "  Installation finished."
      echo "  1. Remove the USB stick."
      echo "  2. After reboot, from the laptop:  ssh ${settings.admin.user}@<server-ip>"
      echo "  3. Copy /etc/nixos/hardware-configuration.nix from the server into"
      echo "     hosts/${host}/ in the repo (see README)."
      echo "=================================================================="
      read -r -p "Press Enter to reboot. " _
      reboot
    '';
  };
in
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  image.baseName = lib.mkForce "${host}-installer";
  # Put the complete server system on the stick, so installing needs no network.
  isoImage.storeContents = [ system disko ];
  # Faster to build; the image is a bit larger.
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  # Run the installer on the first screen instead of a login prompt.
  systemd.services.auto-install = {
    description = "Bluefeed server installer";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-user-sessions.service" "getty-pre.target" ];
    conflicts = [ "getty@tty1.service" ];
    path = [ "/run/current-system/sw" ]; # nix, systemctl, etc. as on the live system
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe installer;
      StandardInput = "tty-force";
      StandardOutput = "tty";
      StandardError = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVTDisallocate = true;
    };
  };
  # Keep boot and service messages off the installer screen.
  boot.kernelParams = [ "quiet" "systemd.show_status=false" ];
  boot.consoleLogLevel = 0;

  # The live system needs no SSH server.
  services.openssh.enable = lib.mkForce false;
}
