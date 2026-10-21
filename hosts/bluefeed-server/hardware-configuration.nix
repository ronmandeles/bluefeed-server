# PLACEHOLDER — this file is overwritten automatically during installation.
#
# scripts/install.sh runs nixos-anywhere with --generate-hardware-config, which
# detects the real server's hardware (disk controller, CPU, network card) and
# writes the result here. Keep the generated version: it is part of the server's
# configuration from then on.
{ modulesPath, ... }:
{
  # Common drivers so the placeholder still boots on most machines and in a VM.
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.initrd.availableKernelModules = [ "ahci" "nvme" "xhci_pci" "usb_storage" "sd_mod" "virtio_pci" "virtio_blk" ];
}
