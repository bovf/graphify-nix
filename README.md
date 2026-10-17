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
checks.${system}.updater-release-selection
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

`nix/apps/update.nix` runs `nix/apps/update-pins.py` for all 17 owned pins:
PyPI's current release/sdist metadata for Graphify, datasketch, jieba-py,
graspologic-native, Nix and HCL; GitHub's stable release metadata for the other
11 parsers. Parser versions respect the candidate Graphify's declared bounds;
when the latest release is incompatible, the updater selects the newest
compatible stable release. It verifies source hashes via PyPI SHA-256 or Nix's
unpacked GitHub prefetch. Swift uses the matching
`<version>-with-generated-files` tag because the plain release omits generated
parser sources. `GITHUB_TOKEN` or `GH_TOKEN` can avoid GitHub API rate limits.
The sole flake input is `nixpkgs`; its lock update also updates the supplied
Python interpreter, internal libraries and remaining parsers. These are not
independently pinned here. Unchanged versions still need an upstream check.
The updater also refreshes graspologic-native's bundled Cargo.lock from its
hash-verified sdist; Nix vendors every locked crate with its recorded checksum.

The updater writes pins before building Graphify, datasketch and the local
system's extraction and package-contract checks; failure leaves the changes
available for review. Build outputs are GC-rooted under a printed temporary
`graphify-update.XXXXXX/result` path (set `TMPDIR` to choose its parent).
The offline `updater-release-selection` check covers constrained selection.
If upstream changes file detection or extract dispatch, refresh
`overlays/graphify/nix-support.patch` against the new sdist, preserving the Nix
extractor and upstream extensions, then rebuild the package and checks without
repeating the pin update. Review `git diff` before committing; successful updating
alone does not test every extra.

### Release audit (2026-10-18)

The full updater selects Graphify **0.9.90 → 0.9.92**, Scala parser
**0.26.2 → 0.26.3**, and nixpkgs
`f20cd90e28fe0403873f473b29e42662cd86e8c4`. The other15 owned pins and
graspologic-native Cargo lock are unchanged after authoritative metadata/hash checks.
PHP0.25.1 is still outside the candidate's `>=0.23,<0.25` bound;0.24.2 remains
latest compatible. The local Nix extractor/patch, extras and wrapper are unchanged.
Both packages and all3 checks build. Private smoke imports18 supplied grammars,
checks8 Pi references/public APIs, extracts inert Nix and runs the CLI. Generated
Graphify skills and MCP integration also pass with Pi1.3.0 in a private AI-only
home. No provider calls, real user data, activation or non-native build claim.

### Historical release audit (2026-10-14)

Full updater: Graphify **0.9.80 → 0.9.90**; nixpkgs advances to
`ca1659429c950a11a565b5764e37a1b704e17ec8`. All sixteen other owned pins and
hash-verified graspologic-native Cargo.lock were checked and stay unchanged.
PHP 0.25.1 remains outside the candidate's `>=0.23,<0.25` bound; 0.24.2 is latest
compatible. No parser constraint is weakened to select a newer release.

Upstream moved detection/extraction context, so `nix-support.patch` was regenerated
against 0.9.90 with the Nix extractor body byte-identical. It applies at exact
current positions with zero fuzz; no upstream extension is removed. Graphify,
datasketch and all three checks build. Private filesystem/network smoke checks
import all eighteen supplied grammars, inspect eight Pi references/public
signatures, extract inert Nix and run the CLI version. An initial fixture wrongly
requested unpackaged HTML instead of supplied JSON; only that fixture was fixed.
No live HOME, credentials, model calls or non-native runtime claim is added.
Effective consumer-followed integration is checked separately.

### Historical release audit (2026-10-08)

Graphify **0.9.80**, all 16 owned dependency pins and graspologic-native's
hash-verified Cargo.lock remain unchanged after the full updater and canonical
release-selector replay. PHP's latest **0.25.1** is outside Graphify's
`>=0.23,<0.25` bound; **0.24.2** remains the newest compatible release.
Nixpkgs remains at the audited `7dd199b0e2993e37b4775ed66b1c291699608c9f`.

The extractor/patch, extras, Python wrapper and package contracts are unchanged.
Graphify, datasketch and all three native checks build. A fresh private
HOME/filesystem/network smoke check imports all 18 installed parser modules,
records the three public extraction signatures, checks the eight Pi references,
extracts an inert Nix fixture and runs `graphify --version`. This is not a full
parser-behavior audit, semantic/model call, activation or non-native runtime test.
Consumer skill/MCP checks remain required under the consumer's actual follows.

### Historical release audit (2026-10-02)

Graphify **0.9.73 → 0.9.74**, checked against
[PyPI metadata](https://pypi.org/pypi/graphifyy/json).
All 16 dependency pins and graspologic-native's hash-verified Cargo.lock remain
unchanged after upstream audit:

| Source | Owned dependency pins checked (unchanged) |
| --- | --- |
| PyPI | datasketch 2.0.0, jieba-py 0.46.12, graspologic-native 1.3.1, tree-sitter-nix 0.1.0, tree-sitter-hcl 1.2.0 |
| GitHub releases | tree-sitter-typescript 0.23.2, tree-sitter-java 0.23.5, tree-sitter-groovy 0.1.2, tree-sitter-c 0.24.2, tree-sitter-cpp 0.23.4, tree-sitter-ruby 0.23.1, tree-sitter-kotlin 1.1.0, tree-sitter-scala 0.26.2, tree-sitter-php 0.24.2, tree-sitter-lua 0.5.0, tree-sitter-swift 0.7.3 |

PHP's latest release is **0.25.0**, but Graphify still requires `>=0.23,<0.25`:
**0.24.2 is the latest compatible release**, not an unaudited hold. The updater
reads parser bounds from candidate Graphify metadata instead of blindly
choosing latest. The PHP license correction and Swift version hook/metadata
relaxation remain. The existing updater completed all authoritative release/hash
audits without credentials; later supplemental GitHub JSON capture hit the
unauthenticated rate limit, so it is partial, not an independent full capture.
Graphify's declared dependency constraints are unchanged.

The full flake-input update advances `nixpkgs-unstable` from
`b6c8664de9b6cc07fe5666a29f91884ba81197c4` (2026-09-29) to
`c9fe7d12cd78d1adcd12dd15e24432dde5b155a0` (2026-09-30), independently confirmed
against the official Git branch ref. Python remains **3.14.7**, tree-sitter **0.25.2**.
Default dependencies include NumPy 2.5.2, MCP 1.29.0, Starlette 1.3.1,
pypdf **6.18.1 → 6.19.0** and Pillow 12.3.0.
Chinese and Leiden retain their Python-version-marked selections; NumPy remains
a core dependency even with `extras = []`.

The updater's first build rejected the old detection patch because upstream added
Verilog-header `.vh` detection. Patch context and line positions were refreshed
without rerunning the updater; the final patch applies with zero fuzz and no
offsets, without changing extractor logic. The extraction check now guards `.vh`
alongside upstream's VB.NET, COBOL, Solidity and Erlang detection;
upstream optional `vbnet`, `r`, `erlang` and `solidity` parser extras are
**not packaged** by this overlay. Detection does not imply grammar availability.

## Verification

```bash
# Use the bounded NIX_CONFIG above.
nix build .#graphify .#datasketch .#checks.x86_64-linux.nix-extraction .#checks.x86_64-linux.package-contracts .#checks.x86_64-linux.updater-release-selection --out-link "$(mktemp -d)/result"
# Run graphify --version only inside a private HOME/filesystem/network sandbox.
nix run .#fmt -- --check
nix flake check
nix flake check --all-systems --no-build
nix flake show --all-systems
```

The x86_64-linux checks cover `graphify 0.9.92`, default extras, an empty extras
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
`graphify/skill-pi.md` and all eight `graphify/skills/pi/references/*.md`;
datasketch remains a separate output, not injected into `graphify-python`.
In the October 2 audit, the Pi skill and all eight references were byte-identical
to 0.9.73, as was the MCP server source. MCP `get_node`/`get_neighbors` retain `label` and `node_id`
(also `id` internally), with no required `label` in their schemas.
In that October 2 audit, public `extract`, `extract_python` and local
`extract_nix` signatures were unchanged. Installed parser imports, resources,
API signatures and CLI version were also checked then in a private
filesystem/network Bubblewrap sandbox with only the read-only Nix store and
inert fixtures exposed. October 7 did not repeat that standalone smoke test. The October 8 check
above is a fresh, separately scoped installed import/resource/signature/CLI check.
CLI startup can refresh stale user skills before even `--version`; do not use
live HOME for smoke tests.
No downstream package, Python path, skill or MCP API migration is required for
this update.
When `graphify-nix.inputs.nixpkgs.follows = "nixpkgs"`, the consumer's lock
selects internal dependency versions instead of this lock;
rebuild and run extraction checks with that consumer's nixpkgs before rollout.
No Home Manager activation or imperative Graphify installation is required here.
