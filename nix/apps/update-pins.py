"""Refresh the overlay's owned pins; --self-test checks constrained selection offline."""

import base64
import json
import os
import re
import subprocess
import sys
import tarfile
import urllib.request
from pathlib import Path

from packaging.requirements import Requirement
from packaging.specifiers import SpecifierSet
from packaging.version import Version


def compatible_release(releases, constraint):
    candidates = [
        release for release in releases
        if not release["draft"] and not release["prerelease"]
        and Version(release["tag_name"].removeprefix("v")) in constraint
    ]
    return max(candidates, key=lambda release: Version(release["tag_name"].removeprefix("v")), default=None)


def get_json(url):
    headers = {"User-Agent": "graphify-nix-update"}
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token and url.startswith("https://api.github.com/"):
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def main():
    pypi_pins = [
        "graphifyy", "datasketch", "jieba-py", "graspologic-native",
        "tree-sitter-nix", "tree-sitter-hcl",
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
    graphify_metadata = get_json("https://pypi.org/pypi/graphifyy/json")
    # Owned parser bounds come from the candidate Graphify, never from a stale pin.
    constraints = {}
    for spec in graphify_metadata["info"]["requires_dist"]:
        requirement = Requirement(spec)
        if requirement.name.startswith("tree-sitter-"):
            constraints[requirement.name] = constraints.get(requirement.name, SpecifierSet()) & requirement.specifier
    cargo_lock = None

    def pypi_pin(pname):
        nonlocal cargo_lock
        metadata = graphify_metadata if pname == "graphifyy" else get_json(f"https://pypi.org/pypi/{pname}/json")
        version = metadata["info"]["version"]
        constraint = constraints.get(pname, SpecifierSet())
        if Version(version) not in constraint:
            versions = [
                Version(candidate) for candidate, files in metadata["releases"].items()
                if Version(candidate) in constraint
                and any(item["packagetype"] == "sdist" and not item["yanked"] for item in files)
            ]
            version = str(max(versions))
            metadata = get_json(f"https://pypi.org/pypi/{pname}/{version}/json")
        sdists = [item for item in metadata["urls"] if item["packagetype"] == "sdist" and not item["yanked"]]
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
        url = f"https://api.github.com/repos/{repo}/releases"
        latest = get_json(f"{url}/latest")
        constraint = constraints.get(pname, SpecifierSet())
        release = compatible_release([latest], constraint)
        if release is None:
            releases = []
            page = 1
            while True:
                batch = get_json(f"{url}?per_page=100&page={page}")
                releases.extend(batch)
                if len(batch) < 100:
                    break
                page += 1
            release = compatible_release(releases, constraint)
            if release is None:
                raise RuntimeError(f"no stable {pname} release satisfies {constraint}")
            print(f"{pname}: latest {latest['tag_name']} excluded by Graphify {constraint}; selected {release['tag_name']}")
        release_tag = release["tag_name"]
        version = release_tag.removeprefix("v")
        source_tag = f"{version}-with-generated-files" if pname == "tree-sitter-swift" else release_tag
        prefetched = json.loads(subprocess.check_output(
            ["nix", "store", "prefetch-file", "--unpack", "--json", f"https://github.com/{repo}/archive/refs/tags/{source_tag}.tar.gz"],
            text=True,
        ))
        return version, prefetched["hash"], source_tag

    path = Path("overlays/graphify/default.nix")
    text = path.read_text()

    def update_pin(pname, version, source_hash, source_tag):
        nonlocal text
        anchors = list(re.finditer(rf'pname = "{re.escape(pname)}";', text))
        if len(anchors) != 1:
            raise RuntimeError(f"expected one {pname} package block, found {len(anchors)}")
        start = anchors[0].start()
        next_anchor = re.search(r'pname = "', text[anchors[0].end():])
        end = anchors[0].end() + next_anchor.start() if next_anchor else len(text)
        block = text[start:end]
        block, version_count = re.subn(r'version = "[^"]+";', f'version = "{version}";', block, count=1)
        block, hash_count = re.subn(r'hash = "[^"]+";', f'hash = "{source_hash}";', block, count=1)
        if version_count != 1 or hash_count != 1:
            raise RuntimeError(f"could not update version/hash for {pname}")
        if source_tag is not None and pname == "tree-sitter-swift":
            block, tag_count = re.subn(r'tag = "[^"]+";', f'tag = "{source_tag}";', block, count=1)
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


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        releases = [
            {"tag_name": tag, "draft": False, "prerelease": False}
            for tag in ["v0.24.1", "v0.25.0", "v0.24.2"]
        ]
        assert compatible_release(releases, SpecifierSet(">=0.23,<0.25"))["tag_name"] == "v0.24.2"
        assert compatible_release(releases, SpecifierSet(">=0.26")) is None
        assert compatible_release(releases, SpecifierSet())["tag_name"] == "v0.25.0"
        releases[-1]["draft"] = True
        assert compatible_release(releases, SpecifierSet("<0.25"))["tag_name"] == "v0.24.1"
        releases[0]["prerelease"] = True
        assert compatible_release(releases, SpecifierSet("<0.25")) is None
        print("constrained release selection: passed")
    else:
        main()
