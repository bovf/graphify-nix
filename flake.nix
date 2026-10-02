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
      updater-release-selection =
        pkgs.runCommand "graphify-updater-release-selection" {
          nativeBuildInputs = [(pkgs.python3.withPackages (ps: [ps.packaging]))];
        } ''
          python3 ${./nix/apps/update-pins.py} --self-test
          touch $out
        '';

      nix-extraction = pkgs.runCommand "graphify-nix-extraction-check" {nativeBuildInputs = [pkgs.graphify];} ''
        cat > check.py <<'PY'
        from copy import deepcopy
        from pathlib import Path

        from graphify.build import build_from_json
        from graphify.detect import CODE_EXTENSIONS, FileType, classify_file
        from graphify.extract import _DISPATCH, _make_id, extract, extract_nix
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
        assert {".nix", ".robot", ".resource", ".vb", ".cobol", ".sol", ".erl", ".vh"} <= CODE_EXTENSIONS
        assert _DISPATCH[".nix"] is extract_nix
        assert _make_id(str(source)) in {node["id"] for node in extraction["nodes"]}
        assert validate_extraction(extraction) == []

        graph = build_from_json(deepcopy(extraction), root=root, directed=True)
        relations = {data["relation"] for _, _, data in graph.edges(data=True)}
        assert {"contains", "imports", "calls"} <= relations
        public_extraction = extract([source], root=root, cache_root=root, parallel=False)
        assert public_extraction["nodes"]
        assert validate_extraction(public_extraction) == []
        PY
        graphify-python check.py
        touch $out
      '';

      package-contracts = let
        minimal = pkgs.graphify.override {extras = [];};
        optional = pkgs.graphify.override {extras = ["mcp" "chinese" "leiden"];};
      in
        pkgs.runCommand "graphify-package-contracts" {} ''
          export HOME="$TMPDIR"
          export MPLCONFIGDIR="$TMPDIR/matplotlib"
          # Requirement validation is a test dependency, not a runtime extra.
          export PYTHONPATH="${pkgs.python3Packages.packaging}/${pkgs.python3.sitePackages}"
          ${minimal}/bin/graphify-python - <<'PY'
          from importlib.metadata import PackageNotFoundError, version
          import graphify
          import numpy
          try:
              version("matplotlib")
          except PackageNotFoundError:
              pass
          else:
              raise AssertionError("extras=[] must replace the default extras")
          PY
          ${pkgs.graphify}/bin/graphify --version
          ${pkgs.graphify}/bin/graphify-python - <<'PY'
          from importlib.metadata import requires, version
          from importlib.resources import files
          from packaging.requirements import Requirement
          from io import BytesIO
          from pathlib import Path
          from graphify.extract import extract_terraform
          import matplotlib
          matplotlib.use("Agg")
          from matplotlib import pyplot
          from pypdf import PdfReader, PdfWriter
          import graphify.serve
          import markdownify
          import tree_sitter_hcl

          terraform = Path("sample.tf")
          terraform.write_text('resource "null_resource" "example" {}\n')
          assert extract_terraform(terraform)["nodes"]
          for spec in requires("graphifyy"):
              requirement = Requirement(spec)
              if any(requirement.marker is None or requirement.marker.evaluate({"extra": extra})
                     for extra in ["", "mcp", "pdf", "svg", "terraform"]):
                  assert version(requirement.name) in requirement.specifier, spec
          resources = files("graphify")
          assert resources.joinpath("skill-pi.md").read_text()
          references = resources.joinpath("skills/pi/references")
          assert references.joinpath("extraction-spec.md").read_text()
          assert references.joinpath("query.md").read_text()
          pdf = BytesIO()
          writer = PdfWriter()
          writer.add_blank_page(width=72, height=72)
          writer.write(pdf)
          assert len(PdfReader(pdf).pages) == 1
          pyplot.plot([0, 1], [0, 1])
          pyplot.savefig("smoke.svg")
          PY
          ${optional}/bin/graphify-python - <<'PY'
          from importlib.metadata import requires, version
          from packaging.requirements import Requirement
          import networkx as nx
          from graphify.cluster import _native_leiden
          from graphify.serve import _jieba, _segment_chinese
          for spec in requires("graphifyy"):
              requirement = Requirement(spec)
              if any(requirement.marker is None or requirement.marker.evaluate({"extra": extra})
                     for extra in ["mcp", "chinese", "leiden"]):
                  assert version(requirement.name) in requirement.specifier, spec
          graph = nx.complete_graph(["a", "b", "c"])
          partition = _native_leiden(graph, resolution=1.0)
          assert partition is not None and set(partition) == set(graph)
          assert _jieba is not None
          assert "自然语言" in _segment_chinese("自然语言处理")
          PY
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
