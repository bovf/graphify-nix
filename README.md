# graphify-nix

Nix flake for `graphifyy` with Badwater's local `.nix` AST extractor.

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
```

Default graphify extras:

```nix
[ "mcp" "pdf" "svg" "terraform" ]
```

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

```bash
nix run .#fmt           # auto-format Nix files with Alejandra
nix run .#fmt -- --check
nix run .#update        # update flake + graphifyy version/hash, then build
nix develop             # installs staged-file Alejandra pre-commit hook
```

If upstream graphify changes around file detection or extract dispatch,
`nix run .#update` may fail during patch application. Refresh
`overlays/graphify/nix-support.patch` manually in that case.

## Quick validation

```bash
nix build .#graphify --no-link
graphify --version
```
