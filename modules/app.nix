# --- Step 7: the application as a non-root systemd service.
#
# The app is NOT built into the system. The deploy user pushes it separately
# (scripts/deploy-app.sh) into a Nix profile, and this service runs whatever
# that profile currently points to. So app releases don't need an OS change.
{ settings, ... }:
let
  app = settings.app;
  profileDir = "/nix/var/nix/profiles/app";
  profile = "${profileDir}/${app.name}";
in
{
  # Dedicated account for the app, without login.
  users.users.${app.name} = {
    isSystemUser = true;
    group = app.name;
  };
  users.groups.${app.name} = { };

  # Profile directory, owned by the deploy user so it can switch app versions.
  systemd.tmpfiles.rules = [
    "d ${profileDir} 0755 ${settings.deploy.user} ${settings.deploy.user} -"
  ];

  systemd.services.${app.name} = {
    description = app.name;
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # Don't fail before the first deploy; start once the app exists.
    unitConfig.ConditionPathExists = "${profile}/bin/${app.binary}";
    environment.PORT = toString app.port;
    serviceConfig = {
      ExecStart = "${profile}/bin/${app.binary}";
      User = app.name;
      Group = app.name;
      Restart = "on-failure";
      RestartSec = 5;
      # Data the app may write lives in /var/lib/<app>.
      StateDirectory = app.name;
      WorkingDirectory = "/var/lib/${app.name}";
      # Sandboxing: the app cannot change the system or see users' files.
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = ""; # no root powers (port must be above 1024)
    };
  };

  # The deploy user may restart the app, and nothing else, with sudo.
  security.sudo.extraRules = [{
    users = [ settings.deploy.user ];
    commands = [{
      command = "/run/current-system/sw/bin/systemctl restart ${app.name}.service";
      options = [ "NOPASSWD" ];
    }];
  }];
}
