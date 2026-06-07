{nixpkgs}: {
  mkApps = system: let
    fmtModule = import ./fmt.nix {inherit nixpkgs;};
    updateModule = import ./update.nix {inherit nixpkgs;};
  in {
    fmt = fmtModule.mkFmtApp system;
    update = updateModule.mkUpdateApp system;
  };
}
