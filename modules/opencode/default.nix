{ lib, osConfig ? { }, ... }:
let
  useOpencodeGo = lib.attrByPath [ "homelab" "opencode" "useOpencodeGo" ] false osConfig;

  defaultModelConfig = {
    # ChatGPT Plus models authenticated through OpenCode's OpenAI provider.
    categories = {
      quick = {
        model = "openai/gpt-5.4-mini-fast";
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

  opencodeGoModelConfig = {
    agents = {
      sisyphus = {
        model = "opencode-go/kimi-k2.7-code";
        fallback_models = [
          { model = "zai-coding-plan/glm-5.2"; }
          { model = "zai-coding-plan/glm-5.1"; }
          {
            model = "openai/gpt-5.6-sol";
            variant = "high";
          }
        ];
      };
      hephaestus = {
        model = "openai/gpt-5.6-sol";
        variant = "medium";
        fallback_models = [
          { model = "zai-coding-plan/glm-5.2"; }
          { model = "zai-coding-plan/glm-5.1"; }
        ];
      };
      oracle = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
        fallback_models = [
          { model = "zai-coding-plan/glm-5.2"; }
          { model = "zai-coding-plan/glm-5.1"; }
          { model = "opencode-go/glm-5.1"; }
        ];
      };
      librarian = {
        model = "zai-coding-plan/glm-5-turbo";
        fallback_models = [
          { model = "zai-coding-plan/glm-4.7"; }
          { model = "zai-coding-plan/glm-5.2"; }
          { model = "zai-coding-plan/glm-5.1"; }
          { model = "openai/gpt-5.4-mini-fast"; }
          { model = "opencode-go/minimax-m3"; }
        ];
      };
      explore = {
        model = "opencode/deepseek-v4-flash-free";
        fallback_models = [
          { model = "zai-coding-plan/glm-5-turbo"; }
          { model = "opencode-go/minimax-m3"; }
          { model = "opencode-go/qwen3.7-plus"; }
          { model = "opencode-go/qwen3.7-max"; }
          { model = "openai/gpt-5.4-mini-fast"; }
        ];
      };
      "multimodal-looker" = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
        fallback_models = [
          { model = "zai-coding-plan/glm-5v-turbo"; }
          { model = "opencode-go/kimi-k2.6"; }
          { model = "openai/gpt-5.4-mini-fast"; }
        ];
      };
      prometheus = {
        model = "zai-coding-plan/glm-5.2";
        fallback_models = [
          { model = "zai-coding-plan/glm-5.1"; }
          { model = "opencode-go/glm-5.1"; }
          {
            model = "openai/gpt-5.6-sol";
            variant = "high";
          }
        ];
      };
      metis = {
        model = "zai-coding-plan/glm-5.2";
        fallback_models = [
          { model = "zai-coding-plan/glm-5.1"; }
          { model = "opencode-go/glm-5.1"; }
          {
            model = "openai/gpt-5.5";
            variant = "high";
          }
        ];
      };
      momus = {
        model = "openai/gpt-5.6-terra";
        variant = "high";
        fallback_models = [
          { model = "zai-coding-plan/glm-5.2"; }
          { model = "zai-coding-plan/glm-5.1"; }
          { model = "opencode-go/glm-5.1"; }
        ];
      };
      atlas = {
        model = "opencode-go/kimi-k2.7-code";
        fallback_models = [
          { model = "zai-coding-plan/glm-5.2"; }
          { model = "opencode-go/qwen3.7-plus"; }
          { model = "opencode-go/qwen3.7-max"; }
          { model = "opencode-go/minimax-m3"; }
          { model = "zai-coding-plan/glm-5.1"; }
          { model = "zai-coding-plan/glm-5-turbo"; }
        ];
      };
      "sisyphus-junior" = {
        model = "zai-coding-plan/glm-5-turbo";
        fallback_models = [
          { model = "zai-coding-plan/glm-4.7"; }
          { model = "opencode-go/kimi-k2.7-code"; }
          { model = "opencode-go/minimax-m3"; }
          {
            model = "openai/gpt-5.6-terra";
            variant = "high";
          }
        ];
      };
    };

    categories = {
      visual-engineering = {
        model = "zai-coding-plan/glm-5v-turbo";
        fallback_models = [
          {
            model = "openai/gpt-5.6-sol";
            variant = "medium";
          }
          { model = "opencode-go/glm-5.1"; }
        ];
      };
      ultrabrain = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
        fallback_models = [
          { model = "zai-coding-plan/glm-5.2"; }
          { model = "zai-coding-plan/glm-5.1"; }
          { model = "opencode-go/glm-5.1"; }
        ];
      };
      deep = {
        model = "openai/gpt-5.6-terra";
        variant = "high";
        fallback_models = [
          { model = "zai-coding-plan/glm-5.2"; }
          { model = "zai-coding-plan/glm-5.1"; }
          { model = "opencode-go/kimi-k2.7-code"; }
          { model = "opencode-go/qwen3.7-plus"; }
          { model = "opencode-go/qwen3.7-max"; }
        ];
      };
      artistry = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
        fallback_models = [
          { model = "opencode-go/kimi-k2.6"; }
          { model = "zai-coding-plan/glm-5.1"; }
        ];
      };
      quick = {
        model = "opencode/deepseek-v4-flash-free";
        fallback_models = [
          { model = "opencode/mimo-v2.5-free"; }
          { model = "opencode/nemotron-3-ultra-free"; }
          { model = "zai-coding-plan/glm-4.5-air"; }
          { model = "opencode-go/minimax-m3"; }
          { model = "openai/gpt-5.4-mini-fast"; }
        ];
      };
      unspecified-low = {
        model = "zai-coding-plan/glm-5-turbo";
        fallback_models = [
          { model = "zai-coding-plan/glm-4.7"; }
          { model = "opencode-go/kimi-k2.7-code"; }
          { model = "opencode-go/minimax-m3"; }
        ];
      };
      unspecified-high = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
        fallback_models = [
          { model = "zai-coding-plan/glm-5.2"; }
          { model = "zai-coding-plan/glm-5.1"; }
          { model = "opencode-go/kimi-k2.7-code"; }
          { model = "opencode-go/qwen3.7-plus"; }
          { model = "opencode-go/qwen3.7-max"; }
        ];
      };
      writing = {
        model = "zai-coding-plan/glm-5.2";
        fallback_models = [
          { model = "zai-coding-plan/glm-5.1"; }
          { model = "openai/gpt-5.6-luna"; }
          { model = "opencode-go/kimi-k2.6"; }
          { model = "opencode-go/minimax-m3"; }
        ];
      };
    };
  };
in
{
  xdg.configFile."opencode/opencode.jsonc".text = builtins.toJSON {
    enabled_providers = [ "openai" ] ++ lib.optionals useOpencodeGo [ "opencode" ];

    plugin = [
      "oh-my-openagent"
      "@cortexkit/opencode-openai-auth@0.4.3"
    ];
  };

  xdg.configFile."opencode/oh-my-openagent.jsonc".text = builtins.toJSON ({
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";

    # Disable Claude Code compatibility hooks. Their transcript hook writes to
    # ~/.claude even when OpenCode is using an OpenAI model.
    disabled_hooks = [
      "claude-code-hooks"
    ];
  } // (if useOpencodeGo then opencodeGoModelConfig else defaultModelConfig));
}
