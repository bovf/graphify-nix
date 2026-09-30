{nixpkgs}: {
  mkUpdateApp = system: let
    pkgs = nixpkgs.legacyPackages.${system};
    update = pkgs.writeShellApplication {
      name = "update";
      runtimeInputs = with pkgs; [coreutils git nix (python3.withPackages (ps: [ps.packaging]))];
      text = ''
        nix flake update
        python3 ${./update-pins.py}

        build_root=$(mktemp -d "''${TMPDIR:-/tmp}/graphify-update.XXXXXX")
        echo "Keeping build outputs at $build_root/result"
        nix build .#graphify .#datasketch ".#checks.${system}.nix-extraction" ".#checks.${system}.package-contracts" --out-link "$build_root/result"
        nix run .#fmt
      '';
    };
  in {
    type = "app";
    program = nixpkgs.lib.getExe update;
  };
}
