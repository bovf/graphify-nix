{nixpkgs}: {
  mkUpdateApp = system: let
    pkgs = nixpkgs.legacyPackages.${system};
    update = pkgs.writeShellApplication {
      name = "update";
      runtimeInputs = with pkgs; [curl jq nix python3 git];
      text = ''
        nix flake update

        latest=$(curl -fsSL https://pypi.org/pypi/graphifyy/json | jq -r '.info.version')
        meta=$(curl -fsSL "https://pypi.org/pypi/graphifyy/$latest/json")
        sha256=$(echo "$meta" | jq -r '.urls[] | select(.packagetype == "sdist") | .digests.sha256' | head -1)
        sri=$(nix hash convert --hash-algo sha256 --to sri "$sha256")

        python3 - "$latest" "$sri" <<'PY'
        import re
        import sys
        from pathlib import Path

        version, sri = sys.argv[1:3]
        path = Path("overlays/graphify/default.nix")
        text = path.read_text()
        text = re.sub(r'(pname = "graphifyy";\n\s*version = ")[^"]+(";)', rf'\g<1>{version}\2', text)
        text = re.sub(r'(pname = "graphifyy";[\s\S]*?hash = ")[^"]+(";)', rf'\g<1>{sri}\2', text, count=1)
        path.write_text(text)
        PY

        nix build .#graphify --no-link
        nix run .#fmt
      '';
    };
  in {
    type = "app";
    program = nixpkgs.lib.getExe update;
  };
}
