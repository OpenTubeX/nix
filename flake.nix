{
  description = "OpenTubeX packages for NixOS, Linux and macOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Nixpkgs 26.05 is the last release supporting Intel Macs. Pin it for
    # x86_64-darwin only, so the other systems keep receiving updates after
    # 26.05 reaches its end of life.
    nixpkgs-x86_64-darwin.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-x86_64-darwin,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        (if system == "x86_64-darwin" then nixpkgs-x86_64-darwin else nixpkgs).legacyPackages.${system};
    in
    {
      packages = forAllSystems (
        system:
        let
          opentubex = (pkgsFor system).callPackage ./package.nix { };
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
          meta.description = self.packages.${system}.opentubex.meta.description;
        };
        opentubex = self.apps.${system}.default;
      });

      overlays.default = final: _prev: {
        opentubex = final.callPackage ./package.nix { };
      };

      checks = forAllSystems (system: {
        package = self.packages.${system}.opentubex;
      });

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}
