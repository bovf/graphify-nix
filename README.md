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
checks.${system}.package-contracts
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

`nix/apps/update.nix` covers all 17 owned pins: PyPI's current release/sdist
metadata for Graphify, datasketch, jieba-py, graspologic-native, Nix and HCL;
GitHub's latest stable release metadata for the other 11 parsers. It verifies source hashes via PyPI SHA-256
or Nix's unpacked GitHub prefetch. Swift uses the matching
`<version>-with-generated-files` tag because the plain release omits generated
parser sources. `GITHUB_TOKEN` or `GH_TOKEN` can avoid GitHub API rate limits.
The sole flake input is `nixpkgs`; its lock update also updates the supplied
Python interpreter, internal libraries and remaining parsers. These are not
independently pinned here. Unchanged versions still need an upstream check.
The updater also refreshes graspologic-native's bundled Cargo.lock from its
hash-verified sdist; Nix vendors every locked crate with its recorded checksum.

The updater writes pins before building Graphify, datasketch and the local
system's extraction and package-contract checks; failure leaves the changes
available for review.
If upstream changes file detection or extract dispatch, refresh
`overlays/graphify/nix-support.patch` against the new sdist, preserving the Nix
extractor and upstream extensions, then rerun the updater. Review `git diff`
before committing; successful updating alone does not test every extra.

### Release audit (2026-09-20)

Graphify **0.9.54 → 0.9.65**, checked against
[PyPI metadata](https://pypi.org/pypi/graphifyy/json).
The patch offsets were refreshed; the local Nix extractor and upstream file
extensions are unchanged. All 14 previously owned dependency pins were audited
and remain the latest releases at their configured sources:

| Source | Owned dependency pins checked (unchanged) |
| --- | --- |
| PyPI | datasketch 2.0.0, tree-sitter-nix 0.1.0, tree-sitter-hcl 1.2.0 |
| GitHub releases | tree-sitter-typescript 0.23.2, tree-sitter-java 0.23.5, tree-sitter-groovy 0.1.2, tree-sitter-c 0.24.2, tree-sitter-cpp 0.23.4, tree-sitter-ruby 0.23.1, tree-sitter-kotlin 1.1.0, tree-sitter-scala 0.26.2, tree-sitter-php 0.24.2, tree-sitter-lua 0.5.0, tree-sitter-swift 0.7.3 |

`nixpkgs-unstable` advanced from `9b9402b959a2276982ddd5ad3652a38b97f7c40b`
(2026-09-03) to `0a3468a402c449992505b6a9fc5b06580141b750` (2026-09-18).
The default closure still uses Python 3.14.7 and tree-sitter 0.25.2. The existing
PHP license correction and Swift version hook/metadata relaxation remain.

Two new PyPI pins preserve existing optional extras under upstream's Python
version markers: **jieba-py 0.46.12** supplies `chinese` on Python >= 3.12;
**graspologic-native 1.3.1** supplies `leiden` on Python >= 3.13 (nixpkgs has
only 1.2.5, below Graphify's declared bound). Older Python versions retain the
original jieba/graspologic selections. The native override reuses nixpkgs'
Rust/Python packaging and upstream's Cargo.lock. NumPy is now a direct core
dependency, including with `extras = []`; SVG also explicitly declares Pillow.

The initial GitHub API audit hit an anonymous rate limit. GitHub's public
`releases/latest` redirects and hash-verified tag archives confirmed the pins;
a subsequent normal updater run rechecked all releases after the reset. No
credentials were inspected or updater retry machinery retained.

## Verification

```bash
# Use the bounded NIX_CONFIG above.
nix build .#graphify .#datasketch .#checks.x86_64-linux.nix-extraction .#checks.x86_64-linux.package-contracts --no-link
nix run .#graphify -- --version
nix run .#fmt -- --check
nix flake check
nix flake check --all-systems --no-build
nix flake show --all-systems
```

The x86_64-linux checks cover `graphify 0.9.65`, default extras, an empty extras
override, and offline Chinese segmentation/native Leiden clustering. The native
Leiden dependency also runs its six upstream Python tests. `package-contracts`
validates installed requirement bounds, Pi skill/reference resources, PDF
round-tripping, SVG rendering and Terraform extraction. `nix-extraction` covers detection, dispatch,
schema validation, contains/imports/calls edges and the public extraction API.
Other supported systems are evaluated only, not built on Linux. Upstream full
Graphify/datasketch test suites, semantic/model calls, external services and
other optional extras are not exercised.
Flake evaluation still reports the pre-existing missing app `meta` warnings.

For `badwater-ai`, the overlay/package API, default extras and Python wrapper
are unchanged. The installed layout remains `lib/python3.14/site-packages`, with
`graphify/skill-pi.md` and `graphify/skills/pi/references/*.md`; datasketch remains
a separate output, not injected into `graphify-python`.
When `graphify-nix.inputs.nixpkgs.follows = "nixpkgs"`, the consumer's lock
selects internal dependency versions instead of this lock;
rebuild and run extraction checks with that consumer's nixpkgs before rollout.
No Home Manager activation or imperative Graphify installation is required here.
