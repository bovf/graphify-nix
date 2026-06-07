{
  pkgs,
  fmtApp,
  ...
}: let
  preCommitHook = pkgs.writeShellScript "pre-commit-fmt" ''
    set -euo pipefail
    cd "$(${pkgs.git}/bin/git rev-parse --show-toplevel)"
    mapfile -t files < <(${pkgs.git}/bin/git diff --cached --name-only --diff-filter=ACMR -- '*.nix')
    [ "''${#files[@]}" -eq 0 ] && exit 0
    exec ${fmtApp.program} --check "''${files[@]}"
  '';
in {
  default = pkgs.mkShell {
    packages = with pkgs; [
      alejandra
      curl
      git
      jq
      nix
      python3
    ];

    shellHook = ''
      if ${pkgs.git}/bin/git rev-parse --git-dir >/dev/null 2>&1; then
        hook_path="$(${pkgs.git}/bin/git rev-parse --git-path hooks/pre-commit)"
        if [ ! -e "$hook_path" ] || [ -L "$hook_path" ]; then
          mkdir -p "$(dirname "$hook_path")"
          ln -sfn "${preCommitHook}" "$hook_path"
        else
          echo "Existing manual pre-commit hook left untouched: $hook_path"
        fi
      fi
    '';
  };
}
