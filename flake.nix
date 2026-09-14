{
  description = "OpenTubeX packages for NixOS, Linux and macOS";

  # Nixpkgs 26.05 is the last release supporting Intel Macs.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          opentubex = pkgs.callPackage ./package.nix { };
        in
        {
          inherit opentubex;
          default = opentubex;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.opentubex}/bin/opentubex";
          meta.description = self.description;
        };
        opentubex = self.apps.${system}.default;
      });

      overlays.default = final: _prev: {
        opentubex = final.callPackage ./package.nix { };
      };

      checks = forAllSystems (system: {
        package = self.packages.${system}.opentubex;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
