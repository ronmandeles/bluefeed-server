{
  description = "Bluefeed physical server: NixOS configuration";

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
      settings = import ./settings.nix;
      pkgs = nixpkgs.legacyPackages.${system};

    in
    {
      # The server.
      nixosConfigurations.server = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs settings; };
        modules = [
          disko.nixosModules.disko
          ./disk.nix
          ./hardware-configuration.nix
          ./configuration.nix
          ./modules/app.nix
        ];
      };

      # A tiny demo web app, for testing the deploy flow before the real app exists.
      packages.${system}.demo-app = pkgs.writeShellApplication {
        name = settings.app.binary;
        runtimeInputs = [ pkgs.python3 ];
        text = ''
          mkdir -p /tmp/www && echo "hello from ${settings.app.name}" > /tmp/www/index.html
          exec python3 -m http.server "''${PORT:-8080}" --directory /tmp/www
        '';
      };

      # Automated security test (tests/server-test.nix). Run: nix flake check
      checks.${system}.server = import ./tests/server-test.nix {
        inherit pkgs inputs settings;
        demoApp = self.packages.${system}.demo-app;
      };
    };
}
