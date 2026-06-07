{
  description = "Nix flake for graphify with Badwater's local Nix support";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

    graphifyOverlay = import ./overlays/graphify {};
  in {
    overlays = {
      default = graphifyOverlay;
      graphify = graphifyOverlay;
    };

    packages = forAllSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
        config.allowUnfree = true;
      };
    in {
      inherit (pkgs) datasketch graphify;
      default = pkgs.graphify;
    });
  };
}
