{ lib, ... }:
{
  xdg.configFile."opencode/opencode.jsonc".text = builtins.toJSON {
    plugin = [
      "oh-my-openagent"
    ];
  };

  xdg.configFile."opencode/oh-my-openagent.jsonc".text = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";

    # Keep existing Copilot model assignments; verify availability with `opencode models`.
    categories = {
      quick = {
        model = "copilot/gpt-4o-mini";
      };
      visual-engineering = {
        model = "copilot/gpt-4o";
      };
      ultrabrain = {
        model = "copilot/o1-preview";
      };
      deep = {
        model = "copilot/o1-mini";
      };
      artistry = {
        model = "copilot/gpt-4o";
      };
      unspecified-low = {
        model = "copilot/gpt-4o-mini";
      };
      unspecified-high = {
        model = "copilot/gpt-4o";
      };
      writing = {
        model = "copilot/gpt-4o-mini";
      };
    };

    # Agent-specific model overrides
    agents = {
      oracle = {
        model = "copilot/gpt-4o";
      };
      librarian = {
        model = "copilot/gpt-4o-mini";
      };
      explore = {
        model = "copilot/gpt-4o-mini";
      };
    };
  };

  # Remove the previous Nix-managed config name without touching user-owned files.
  home.activation.removeLegacyOhMyOpenCodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    legacyConfig="$HOME/.config/opencode/oh-my-opencode.jsonc"

    if [ -L "$legacyConfig" ]; then
      case "$(readlink -f "$legacyConfig")" in
        /nix/store/*)
          rm -- "$legacyConfig"
          ;;
      esac
    fi
  '';
}
