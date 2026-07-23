_:
{
  xdg.configFile."opencode/opencode.jsonc".text = builtins.toJSON {
    enabled_providers = [
      "openai"
    ];

    plugin = [
      "oh-my-openagent"
      "@cortexkit/opencode-openai-auth@0.4.3"
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
        variant = "high";
      };
      ultrabrain = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
      };
      deep = {
        model = "openai/gpt-5.6-terra";
        variant = "high";
      };
      artistry = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
      };
      unspecified-low = {
        model = "openai/gpt-5.6-luna";
      };
      unspecified-high = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
      };
      writing = {
        model = "openai/gpt-5.6-luna";
      };
    };

    # Agent-specific model overrides
    agents = {
      sisyphus = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
      };
      oracle = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
      };
      librarian = {
        model = "openai/gpt-5.4-mini-fast";
      };
      explore = {
        model = "openai/gpt-5.4-mini-fast";
      };
      "multimodal-looker" = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
      };
      hephaestus = {
        model = "openai/gpt-5.6-sol";
        variant = "medium";
      };
      prometheus = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
      };
      metis = {
        model = "openai/gpt-5.5";
      };
      momus = {
        model = "openai/gpt-5.6-terra";
        variant = "high";
      };
      atlas = {
        model = "openai/gpt-5.5";
      };
    };
  };
}
