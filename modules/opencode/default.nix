{ ... }:
{
  xdg.configFile."opencode/opencode.jsonc".text = builtins.toJSON {
    plugin = [
      "oh-my-opencode"
    ];
  };

  xdg.configFile."opencode/oh-my-opencode.jsonc".text = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";

    # Configure categories with Copilot-available models
    # GitHub Copilot supports: gpt-4o, gpt-4o-mini, o1-preview, o1-mini
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
}
