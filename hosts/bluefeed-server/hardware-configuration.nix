# PLACEHOLDER — this file is overwritten automatically during installation.
#
# scripts/install.sh (nixos-anywhere --generate-hardware-config) or the USB
# installer from `make iso` (saves it as /etc/nixos/hardware-configuration.nix
# on the server, copy it here) detects the real server's hardware (disk
# controller, CPU, network card). Keep the generated version: it is part of the server's
# configuration from then on.
{ modulesPath, ... }:
{
  # Common drivers so the placeholder still boots on most machines and in a VM.
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.initrd.availableKernelModules = [ "ahci" "nvme" "xhci_pci" "usb_storage" "sd_mod" "virtio_pci" "virtio_blk" ];
}
