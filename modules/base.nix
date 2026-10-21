# The server's security baseline. Each section matches a step in the guide.
{ config, lib, pkgs, inputs, settings, ... }:
let
  lan = lib.concatStringsSep ", " settings.lanSubnets;
in
{
  system.stateVersion = "26.05"; # Do not change after install.

  networking.hostName = settings.hostName;
  time.timeZone = settings.timeZone;

  # Bootloader: GRUB, installed for both BIOS and UEFI (see disk.nix).
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    configurationLimit = 10; # keep /boot from filling up with old versions
  };

  # --- Step 2+5: firewall. No inbound access from the internet; only the LAN
  # may reach SSH and the app port. Outbound traffic is allowed.
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ]; # nothing open to the world
    extraInputRules = ''
      ip saddr { ${lan} } tcp dport { 22, ${toString settings.app.port} } accept
    '';
  };

  # --- Step 3: SSH with keys only, no root login, only our two accounts.
  services.openssh = {
    enable = true;
    openFirewall = false; # the firewall rule above decides who may connect
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ settings.admin.user settings.deploy.user ];
    };
  };

  # Accounts.
  users.users.${settings.admin.user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # may use sudo
    openssh.authorizedKeys.keys = settings.admin.sshKeys;
  };
  users.users.${settings.deploy.user} = {
    isNormalUser = true; # needs a shell for `nix copy` over SSH; NOT in wheel
    openssh.authorizedKeys.keys = settings.deploy.sshKeys;
  };
  # The admin has no password (keys only), so sudo cannot ask for one.
  security.sudo.wheelNeedsPassword = false;

  # --- Step 4: automatic security updates, every night at 04:00.
  # The server rebuilds its own configuration (a copy of this folder) against
  # the newest packages of the same NixOS release. It does not reboot by
  # itself; a new kernel takes effect at the next reboot.
  system.autoUpgrade = {
    enable = true;
    flake = "path:${inputs.self}#${settings.hostName}";
    upgrade = false;
    flags = [
      "--override-input" "nixpkgs" "github:NixOS/nixpkgs/nixos-26.05"
      "--no-write-lock-file"
    ];
    dates = "04:00";
    randomizedDelaySec = "30min";
    allowReboot = false;
  };

  # --- Step 6: Nix with flakes; the deploy user may push unsigned packages.
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" settings.deploy.user ]; # signing deferred
    allowed-users = [ "@wheel" settings.deploy.user ];
  };
  # Clean up old packages weekly.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Small set of tools for whoever has to troubleshoot on the server.
  environment.systemPackages = with pkgs; [ vim git htop ];
}
