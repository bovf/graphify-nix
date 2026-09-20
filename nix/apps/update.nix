{nixpkgs}: {
  mkUpdateApp = system: let
    pkgs = nixpkgs.legacyPackages.${system};
    update = pkgs.writeShellApplication {
      name = "update";
      runtimeInputs = with pkgs; [git nix python3];
      text = ''
        nix flake update

        python3 <<'PY'
        import base64
        import json
        import os
        import re
        import subprocess
        import tarfile
        import urllib.request
        from pathlib import Path

        pypi_pins = [
            "graphifyy",
            "datasketch",
            "jieba-py",
            "graspologic-native",
            "tree-sitter-nix",
            "tree-sitter-hcl",
        ]
        github_pins = {
            "tree-sitter-typescript": "tree-sitter/tree-sitter-typescript",
            "tree-sitter-java": "tree-sitter/tree-sitter-java",
            "tree-sitter-groovy": "amaanq/tree-sitter-groovy",
            "tree-sitter-c": "tree-sitter/tree-sitter-c",
            "tree-sitter-cpp": "tree-sitter/tree-sitter-cpp",
            "tree-sitter-ruby": "tree-sitter/tree-sitter-ruby",
            "tree-sitter-kotlin": "tree-sitter-grammars/tree-sitter-kotlin",
            "tree-sitter-scala": "tree-sitter/tree-sitter-scala",
            "tree-sitter-php": "tree-sitter/tree-sitter-php",
            "tree-sitter-lua": "tree-sitter-grammars/tree-sitter-lua",
            "tree-sitter-swift": "alex-pinkus/tree-sitter-swift",
        }

        def get_json(url):
            headers = {"User-Agent": "graphify-nix-update"}
            token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
            if token and url.startswith("https://api.github.com/"):
                headers["Authorization"] = f"Bearer {token}"
            request = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(request) as response:
                return json.load(response)

        cargo_lock = None

        def pypi_pin(pname):
            global cargo_lock
            metadata = get_json(f"https://pypi.org/pypi/{pname}/json")
            version = metadata["info"]["version"]
            sdists = [item for item in metadata["urls"] if item["packagetype"] == "sdist"]
            if len(sdists) != 1:
                raise RuntimeError(f"expected one {pname} {version} sdist, found {len(sdists)}")
            digest = bytes.fromhex(sdists[0]["digests"]["sha256"])
            source_hash = "sha256-" + base64.b64encode(digest).decode()
            if pname == "graspologic-native":
                prefetched = json.loads(subprocess.check_output(
                    ["nix", "store", "prefetch-file", "--json", "--expected-hash", source_hash, sdists[0]["url"]],
                    text=True,
                ))
                with tarfile.open(prefetched["storePath"]) as archive:
                    cargo_lock = archive.extractfile(f"graspologic_native-{version}/Cargo.lock").read()
            return version, source_hash, None

        def github_pin(pname, repo):
            release_tag = get_json(f"https://api.github.com/repos/{repo}/releases/latest")["tag_name"]
            version = release_tag.removeprefix("v")
            source_tag = (
                f"{version}-with-generated-files"
                if pname == "tree-sitter-swift"
                else release_tag
            )
            url = f"https://github.com/{repo}/archive/refs/tags/{source_tag}.tar.gz"
            prefetched = json.loads(subprocess.check_output(
                ["nix", "store", "prefetch-file", "--unpack", "--json", url],
                text=True,
            ))
            return version, prefetched["hash"], source_tag

        path = Path("overlays/graphify/default.nix")
        text = path.read_text()

        def update_pin(pname, version, source_hash, source_tag):
            global text
            anchors = list(re.finditer(rf'pname = "{re.escape(pname)}";', text))
            if len(anchors) != 1:
                raise RuntimeError(f"expected one {pname} package block, found {len(anchors)}")
            start = anchors[0].start()
            next_anchor = re.search(r'pname = "', text[anchors[0].end():])
            end = anchors[0].end() + next_anchor.start() if next_anchor else len(text)
            block = text[start:end]
            block, version_count = re.subn(
                r'version = "[^"]+";', f'version = "{version}";', block, count=1
            )
            block, hash_count = re.subn(
                r'hash = "[^"]+";', f'hash = "{source_hash}";', block, count=1
            )
            if version_count != 1 or hash_count != 1:
                raise RuntimeError(f"could not update version/hash for {pname}")
            if source_tag is not None and pname == "tree-sitter-swift":
                block, tag_count = re.subn(
                    r'tag = "[^"]+";', f'tag = "{source_tag}";', block, count=1
                )
                if tag_count != 1:
                    raise RuntimeError(f"could not update source tag for {pname}")
            text = text[:start] + block + text[end:]
            print(f"{pname}: {version} ({source_hash})")

        for pname in pypi_pins:
            update_pin(pname, *pypi_pin(pname))
        for pname, repo in github_pins.items():
            update_pin(pname, *github_pin(pname, repo))

        path.write_text(text)
        Path("overlays/graphify/graspologic-native-Cargo.lock").write_bytes(cargo_lock)
        PY

        nix build .#graphify .#datasketch ".#checks.${system}.nix-extraction" ".#checks.${system}.package-contracts" --no-link
        nix run .#fmt
      '';
    };
  in {
    type = "app";
    program = nixpkgs.lib.getExe update;
  };
}
