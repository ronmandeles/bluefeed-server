# ---------------------------------------------------------------------------
# settings.nix — the ONLY file you need to edit before installing.
# Every value specific to this server lives here; all other files read it.
# The server's name is the name of this folder (hosts/<name>/).
# The README explains how to find each value (questions Q1–Q5).
# ---------------------------------------------------------------------------
{
  # Time zone.
  timeZone = "Asia/Jerusalem";

  # Q3. Disk that will be ERASED and installed on. Prefer the stable name from
  # `ls -l /dev/disk/by-id/`, e.g. "/dev/disk/by-id/nvme-Samsung_SSD_980_...".
  disk = "/dev/sda";

  # Q2. Home network that may reach SSH and the app. Everything else is dropped.
  lanSubnets = [ "192.168.1.0/24" ];

  # Q4. Administrator account (SSH key only, may use sudo).
  admin = {
    user = "ilya";
    sshKeys = [
      # Required: Ilya's public key.
      "ssh-ed25519 AAAA_REPLACE_WITH_ILYA_PUBLIC_KEY ilya@laptop"
      # Optional: Ron's key, only if Ron needs to log in. Remove the # to enable.
      # "ssh-ed25519 AAAA... ron@laptop"
    ];
  };

  # Q5. Deploy account: receives the app with `nix copy` and restarts it.
  # It is NOT an administrator.
  deploy = {
    user = "deploy";
    sshKeys = [
      "ssh-ed25519 AAAA_REPLACE_WITH_DEPLOY_PUBLIC_KEY deploy@laptop"
    ];
  };

  # The application. Filled in by Ron; no need to change.
  app = {
    name = "myapp";
    port = 8080;
    # Name of the executable inside the app's Nix package (…/bin/<binary>).
    binary = "myapp";
  };
}
