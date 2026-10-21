# Automated security test: starts the server configuration in throw-away VMs and
# checks, by itself, that every rule of the guide really holds.
# Run with:  nix flake check   (or: nix build .#checks.x86_64-linux.server -L)
#
# Network in the test:
#   lan      (192.168.1.x) — a laptop on the home network: SHOULD get in
#   outsider (192.168.2.x) — a machine outside the allowed subnet: should NOT
{ pkgs, inputs, settings, demoApp }:
let
  keys = import "${inputs.nixpkgs}/nixos/tests/ssh-keys.nix" pkgs;
  testSettings = settings // {
    lanSubnets = [ "192.168.1.0/24" ];
    admin = settings.admin // { sshKeys = [ keys.snakeOilPublicKey ]; };
    deploy = settings.deploy // { sshKeys = [ keys.snakeOilPublicKey ]; };
  };
  inherit (testSettings) app admin deploy;
  port = toString app.port;
  host = testSettings.hostName; # the server answers to its own hostname
  ssh = "ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5";
  client = {
    environment.systemPackages = [ pkgs.curl pkgs.netcat ];
    system.extraDependencies = [ demoApp ];
    nix.settings.experimental-features = [ "nix-command" ];
  };
in
pkgs.testers.runNixOSTest {
  name = "server-security";

  nodes.server = { lib, ... }: {
    imports = [ ../modules/base.nix ../modules/app.nix ];
    virtualisation.vlans = [ 1 2 ];
    # The test VM boots without a disk layout or bootloader, and offline.
    boot.loader.grub.enable = lib.mkForce false;
    system.autoUpgrade.enable = lib.mkForce false;
  };
  nodes.lan = client // { virtualisation.vlans = [ 1 ]; };
  nodes.outsider = client // { virtualisation.vlans = [ 2 ]; };
  node.specialArgs = { inherit inputs; settings = testSettings; };

  testScript = ''
    start_all()
    server.wait_for_unit("sshd.service")
    server.wait_for_unit("nftables.service")
    for m in (lan, outsider):
        m.wait_for_unit("multi-user.target")
        m.succeed("mkdir -p ~/.ssh && cp ${keys.snakeOilPrivateKey} ~/.ssh/id_ed25519 && chmod 600 ~/.ssh/id_ed25519")

    with subtest("admin can log in with a key and use sudo"):
        lan.succeed("${ssh} ${admin.user}@${host} 'sudo -n true'")

    with subtest("root login is refused"):
        lan.fail("${ssh} root@${host} true")

    with subtest("password login is not offered"):
        out = lan.succeed("${ssh} -v -o PreferredAuthentications=none ${admin.user}@${host} true 2>&1 || true")
        assert "password" not in out.split("Authentications that can continue:")[-1].split("\n")[0], out

    with subtest("deploy user cannot become root"):
        lan.fail("${ssh} ${deploy.user}@${host} 'sudo -n true'")

    with subtest("deploy flow: nix copy, switch profile, restart, app answers on the LAN"):
        lan.succeed("NIX_SSHOPTS='-o StrictHostKeyChecking=no' nix copy --no-check-sigs --to ssh-ng://${deploy.user}@${host} ${demoApp}")
        lan.succeed("${ssh} ${deploy.user}@${host} 'nix-env -p /nix/var/nix/profiles/app/${app.name} --set ${demoApp} && sudo systemctl restart ${app.name}.service'")
        server.wait_for_open_port(${port})
        lan.succeed("curl -sf http://${host}:${port}/ | grep hello")
        server.succeed("systemctl show -p User --value ${app.name}.service | grep -x ${app.name}")

    with subtest("outside the allowed subnet nothing is reachable"):
        # the server's address on the outsider's network
        ip = server.succeed("ip -4 -o addr | grep -o '192[.]168[.]2[.][0-9]*'").strip()
        outsider.succeed(f"ping -c 1 -W 3 {ip}")  # the network itself works...
        outsider.fail(f"nc -z -w 3 {ip} 22")  # ...but SSH is blocked
        outsider.fail(f"curl -sf -m 3 http://{ip}:${port}/")  # ...and so is the app
  '';
}
