# pi-graphify

Standalone Nix flake for graphify with Badwater's local Nix AST support.

This flake is package/build logic only. Home Manager integration lives in
`badwater-ai`; pi packages live in `pi-nix`.

## Outputs

```nix
overlays.default
overlays.graphify
packages.${system}.graphify
packages.${system}.datasketch
```

## Consumer example

```nix
inputs.pi-graphify = {
  url = "path:/Users/dobrynikolov/Documents/Develop/Nix/repos/pi-graphify";
  inputs.nixpkgs.follows = "nixpkgs";
};

# In nixpkgs overlays:
inputs.pi-graphify.overlays.default
```
