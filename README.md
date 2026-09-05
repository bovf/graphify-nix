# graphify-nix

Nix flake for [`graphifyy`](https://github.com/Graphify-Labs/graphify) with Badwater's local `.nix` AST extractor.

This repo is package/build logic only. Home Manager integration lives in
[`badwater-ai`](git@gitlab.dobryops.com:nix/badwater-ai.git); host choices live
in `pl-badwater`.

## Remote

```text
git@gitlab.dobryops.com:nix/graphify-nix.git
```

## Local patch

The local patch only adds:

```text
.nix detection
extract_nix for Nix attr bindings, imports, module options/config, and calls
```

## Outputs

```nix
overlays.default
overlays.graphify
packages.${system}.graphify
packages.${system}.datasketch
checks.${system}.nix-extraction
```

Supported systems: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`.
The package provides `graphify`, `graphify-mcp`, and `graphify-python` (Python
with Graphify and the selected dependencies importable). Use `graphify-python`
for skill snippets instead of installing packages with pip/uv.

Default graphify extras:

```nix
[ "mcp" "pdf" "svg" "terraform" ]
```

Other packaged extras are listed in `extrasMap` in
`overlays/graphify/default.nix` and selected with
`pkgs.graphify.override { extras = [ "mcp" "pdf" "svg" "terraform" "office" ]; }`.
This replaces, rather than extends, the default list. Not every upstream extra
or grammar is packaged: see `unpackagedParsers` in the same file; their metadata
requirements are removed, not their missing functionality implemented.
`datasketch` is a separate output, not injected into `graphify-python` by default.

## Consumer example

```nix
inputs.graphify-nix = {
  url = "git+ssh://git@gitlab.dobryops.com/nix/graphify-nix.git";
  inputs.nixpkgs.follows = "nixpkgs";
};

# In nixpkgs overlays:
inputs.graphify-nix.overlays.default
```

Then `badwater-ai` can consume `pkgs.graphify` via:

```nix
badwater.ai.graphify.enable = true;
badwater.ai.graphify.package = pkgs.graphify;
```

## Apps / development

Run from the repository root on an update branch. Bound builds in this shell
without overwriting existing Nix configuration:

```bash
export NIX_CONFIG="${NIX_CONFIG-}"$'\nmax-jobs = 2\ncores = 4'
nix run .#fmt           # auto-format Nix files with Alejandra
nix run .#fmt -- --check
nix run .#update        # update every flake input + owned pin, build, then format
nix develop             # installs staged-file Alejandra pre-commit hook
```

`nix/apps/update.nix` covers all 15 owned pins: PyPI's current release/sdist
metadata for Graphify, datasketch, Nix and HCL; GitHub's latest stable release
metadata for the other 11 parsers. It verifies source hashes via PyPI SHA-256
or Nix's unpacked GitHub prefetch. Swift uses the matching
`<version>-with-generated-files` tag because the plain release omits generated
parser sources. `GITHUB_TOKEN` or `GH_TOKEN` can avoid GitHub API rate limits.
The sole flake input is `nixpkgs`; its lock update also updates the supplied
Python interpreter, internal libraries and remaining parsers. These are not
independently pinned here. Unchanged versions still need an upstream check.

The updater writes pins before building Graphify, datasketch and the local
system's Nix extraction check; failure leaves the changes available for review.
If upstream changes file detection or extract dispatch, refresh
`overlays/graphify/nix-support.patch` against the new sdist, preserving the Nix
extractor and upstream extensions, then rerun the updater. Review `git diff`
before committing; successful updating alone does not test every extra.

### Release audit (2026-09-05)

Graphify **0.9.48 → 0.9.54**, checked against
[PyPI metadata](https://pypi.org/pypi/graphifyy/json) (sdist published 2026-09-05).
The detection patch was refreshed for upstream's `.robot`/`.resource`
extensions; the local Nix extractor is unchanged.
All owned dependency versions remain the latest releases at their configured
sources:

| Source | Owned dependency pins checked (unchanged) |
| --- | --- |
| PyPI | datasketch 2.0.0, tree-sitter-nix 0.1.0, tree-sitter-hcl 1.2.0 |
| GitHub releases | tree-sitter-typescript 0.23.2, tree-sitter-java 0.23.5, tree-sitter-groovy 0.1.2, tree-sitter-c 0.24.2, tree-sitter-cpp 0.23.4, tree-sitter-ruby 0.23.1, tree-sitter-kotlin 1.1.0, tree-sitter-scala 0.26.2, tree-sitter-php 0.24.2, tree-sitter-lua 0.5.0, tree-sitter-swift 0.7.3 |

`nixpkgs-unstable` advanced from `a831408e6378bc02ebf8cc09b52c96ca86f6bab4`
(2026-08-22) to `9b9402b959a2276982ddd5ad3652a38b97f7c40b` (2026-09-03).
The default closure uses Python 3.14.7 and tree-sitter 0.25.2. The existing PHP
license correction and Swift version hook/metadata relaxation remain in place.

## Verification

```bash
# Use the bounded NIX_CONFIG above.
nix build .#graphify .#datasketch .#checks.x86_64-linux.nix-extraction --no-link
nix run .#graphify -- --version
nix run .#fmt -- --check
nix flake check
nix flake check --all-systems --no-build
nix flake show --all-systems
```

Verified for this update: all three x86_64-linux builds, `graphify 0.9.54`,
formatting, flake checks, and `graphify-python` imports for the default extras
plus Nix extraction through the public `graphify.extract.extract` API.
The executable `nix-extraction` check covers detection (including preservation
of upstream's new extensions), dispatch, extraction schema validation and graph
construction with contains/imports/calls edges.
Other supported systems were evaluated only, not built on Linux. Upstream full
test suites, external services and non-default extras were not exercised.
Flake evaluation still reports the pre-existing missing app `meta` warnings.

For `badwater-ai`, the overlay/package API, default extras and Python wrapper
are unchanged. When `graphify-nix.inputs.nixpkgs.follows = "nixpkgs"`, the
consumer's lock selects internal dependency versions instead of this lock;
rebuild and run extraction checks with that consumer's nixpkgs before rollout.
No Home Manager activation or imperative Graphify installation is required here.
