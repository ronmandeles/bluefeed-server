{
  description = "Bluefeed servers: NixOS configuration";

  inputs = {
    # NixOS stable release. Changing this line = moving to a new release.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # disko: describes the disk layout in code and partitions the disk at install time.
    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = nixpkgs.legacyPackages.${system};

      # Every folder under hosts/ is one server; the folder name is its hostname.
      hosts = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./hosts));
      settingsFor = host: import ./hosts/${host}/settings.nix // { hostName = host; };

      # A tiny demo web app, for testing the deploy flow before the real app exists.
      demoApp = settings: pkgs.writeShellApplication {
        name = settings.app.binary;
        runtimeInputs = [ pkgs.python3 ];
        text = ''
          mkdir -p /tmp/www && echo "hello from ${settings.app.name}" > /tmp/www/index.html
          exec python3 -m http.server "''${PORT:-8080}" --directory /tmp/www
        '';
      };
    in
    {
      # One NixOS system per host. Shared modules + the host's own two files.
      nixosConfigurations = lib.genAttrs hosts (host: lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; settings = settingsFor host; };
        modules = [
          disko.nixosModules.disko
          ./modules/disk.nix
          ./modules/base.nix
          ./modules/app.nix
          ./hosts/${host}/hardware-configuration.nix
        ];
      });

      # Demo app per host, e.g. .#bluefeed-server-demo-app
      packages.${system} = lib.listToAttrs (map (host: {
        name = "${host}-demo-app";
        value = demoApp (settingsFor host);
      }) hosts);

      # Automated security test per host (tests/server-test.nix). Run: nix flake check
      checks.${system} = lib.genAttrs hosts (host: import ./tests/server-test.nix {
        inherit pkgs inputs;
        settings = settingsFor host;
        demoApp = self.packages.${system}."${host}-demo-app";
      });
    };
}
