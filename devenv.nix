{ pkgs, lib, config, inputs, ... }:

{
  cachix.enable = false;

  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [
    pkgs.git
    pkgs.nixpkgs-fmt
    pkgs.nil
    pkgs.statix
    pkgs.nix-tree
  ];

  # https://devenv.sh/languages/
  languages.nix.enable = true;

  # https://devenv.sh/processes/
  # no need

  # https://devenv.sh/services/
  # no need

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  enterShell = "" +
    "  echo 'NixOS config project environment ready!'\n" +
    "  echo 'Use `nixpkgs-fmt` to format your Nix code.'\n" +
    "  echo 'Use `statix` to lint your Nix code.'\n" +
    "  echo 'Use `nil` for Nix LSP support in your editor.'\n";

  # https://devenv.sh/tasks/
  # no need

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    pre-commit run --all-files
  '';

  # https://devenv.sh/git-hooks/
  git-hooks.hooks = {
    check-added-large-files.enable = false;
    check-yaml.enable = true;
    end-of-file-fixer.enable = true;
    shellcheck.enable = true;
    trim-trailing-whitespace.enable = true;
    yamllint.enable = true;
  };

  # See full reference at https://devenv.sh/reference/options/
}
