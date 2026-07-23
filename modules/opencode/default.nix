_:
{
  xdg.configFile."opencode/opencode.jsonc".text = builtins.toJSON {
    plugin = [
      "oh-my-openagent"
    ];
  };

  xdg.configFile."opencode/oh-my-openagent.jsonc".text = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";

    # ChatGPT Plus models authenticated through OpenCode's OpenAI provider.
    categories = {
      quick = {
        model = "openai/gpt-5.4-mini";
      };
      visual-engineering = {
        model = "openai/gpt-5.6-sol";
      };
      ultrabrain = {
        model = "openai/gpt-5.6-sol";
      };
      deep = {
        model = "openai/gpt-5.6-terra";
      };
      artistry = {
        model = "openai/gpt-5.6-sol";
      };
      unspecified-low = {
        model = "openai/gpt-5.6-luna";
      };
      unspecified-high = {
        model = "openai/gpt-5.6-sol";
      };
      writing = {
        model = "openai/gpt-5.6-luna";
      };
    };

    # Agent-specific model overrides
    agents = {
      oracle = {
        model = "openai/gpt-5.6-sol";
      };
      librarian = {
        model = "openai/gpt-5.4-mini-fast";
      };
      explore = {
        model = "openai/gpt-5.4-mini-fast";
      };
    };
  };
}
