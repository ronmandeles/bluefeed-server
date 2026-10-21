# Disk layout, used by disko at install time. WARNING: installing ERASES this disk.
#
# Works on both UEFI and old BIOS machines, so we don't need to know which one
# the server is:
#   - 1M  "boot"  partition for GRUB on BIOS machines
#   - 512M "ESP"  partition for GRUB on UEFI machines (mounted at /boot)
#   - rest "root" partition, ext4, mounted at /
{ settings, ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    device = settings.disk;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02"; # BIOS boot partition
        };
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
