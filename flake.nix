{
  description = "Nix flake for graphify with Badwater's local Nix support";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];

    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

    appsLib = import ./nix/apps {inherit nixpkgs;};
    shellsLib = import ./nix/shells;

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

    checks = forAllSystems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };
    in {
      nix-extraction = pkgs.runCommand "graphify-nix-extraction-check" {nativeBuildInputs = [pkgs.graphify];} ''
        cat > check.py <<'PY'
        from copy import deepcopy
        from pathlib import Path

        from graphify.build import build_from_json
        from graphify.detect import FileType, classify_file
        from graphify.extract import _DISPATCH, _make_id, extract_nix
        from graphify.validate import validate_extraction

        root = Path.cwd()
        (root / "other.nix").write_text("{ value = 1; }\n")
        source = root / "sample.nix"
        source.write_text(
            "{ lib, ... }: {\n"
            "  imports = [ ./other.nix ];\n"
            "  services.demo.enable = true;\n"
            "  result = lib.mkIf true { answer = builtins.toString 42; };\n"
            "}\n"
        )

        extraction = extract_nix(source)
        assert classify_file(source) == FileType.CODE
        assert _DISPATCH[".nix"] is extract_nix
        assert _make_id(str(source)) in {node["id"] for node in extraction["nodes"]}
        assert validate_extraction(extraction) == []

        graph = build_from_json(deepcopy(extraction), root=root, directed=True)
        relations = {data["relation"] for _, _, data in graph.edges(data=True)}
        assert {"contains", "imports", "calls"} <= relations
        PY
        graphify-python check.py
        touch $out
      '';
    });

    apps = forAllSystems (system: appsLib.mkApps system);

    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      apps = appsLib.mkApps system;
    in
      shellsLib {
        inherit pkgs;
        fmtApp = apps.fmt;
      });
  };
}
