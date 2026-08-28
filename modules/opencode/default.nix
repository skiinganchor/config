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
    # Roster uses only the enabled providers (openai + opencode-go) and follows
    # the oh-my-openagent recommended stack for OpenCode Go subscribers.
    agents = {
      sisyphus = {
        model = "opencode-go/kimi-k3";
        fallback_models = [
          { model = "opencode-go/glm-5.2"; }
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
          { model = "opencode-go/glm-5.2"; }
        ];
      };
      oracle = {
        model = "openai/gpt-5.6-sol";
        variant = "high";
        fallback_models = [
          { model = "opencode-go/glm-5.2"; }
        ];
      };
      librarian = {
        model = "opencode-go/qwen3.7-plus";
        fallback_models = [
          { model = "opencode-go/minimax-m3"; }
          { model = "opencode-go/minimax-m2.7"; }
          { model = "openai/gpt-5.4-mini-fast"; }
        ];
      };
      explore = {
        model = "opencode-go/qwen3.7-plus";
        fallback_models = [
          { model = "opencode-go/minimax-m3"; }
          { model = "opencode-go/minimax-m2.7"; }
          { model = "openai/gpt-5.4-mini-fast"; }
        ];
      };
      "multimodal-looker" = {
        model = "opencode-go/kimi-k3";
        variant = "high";
        fallback_models = [
          { model = "opencode-go/glm-5.2"; }
          {
            model = "openai/gpt-5.6-sol";
            variant = "medium";
          }
        ];
      };
      prometheus = {
        model = "opencode-go/kimi-k2.7-code";
        fallback_models = [
          { model = "opencode-go/glm-5.2"; }
          {
            model = "openai/gpt-5.6-sol";
            variant = "high";
          }
        ];
      };
      metis = {
        model = "opencode-go/glm-5.2";
        fallback_models = [
          {
            model = "openai/gpt-5.6-sol";
            variant = "high";
          }
        ];
      };
      momus = {
        model = "openai/gpt-5.6-terra";
        variant = "high";
        fallback_models = [
          { model = "opencode-go/glm-5.2"; }
        ];
      };
      atlas = {
        model = "opencode-go/kimi-k3";
        fallback_models = [
          { model = "opencode-go/qwen3.7-plus"; }
          { model = "opencode-go/minimax-m3"; }
          { model = "opencode-go/minimax-m2.7"; }
        ];
      };
      "sisyphus-junior" = {
        model = "opencode-go/kimi-k2.7-code";
        fallback_models = [
          { model = "opencode-go/qwen3.7-plus"; }
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
        model = "opencode-go/kimi-k3";
        variant = "max";
        fallback_models = [
          {
            model = "openai/gpt-5.6-sol";
            variant = "medium";
          }
          { model = "opencode-go/glm-5.2"; }
        ];
      };
      ultrabrain = {
        model = "openai/gpt-5.6-sol";
        variant = "xhigh";
        fallback_models = [
          { model = "opencode-go/glm-5.2"; }
        ];
      };
      deep = {
        model = "openai/gpt-5.6-sol";
        variant = "medium";
        fallback_models = [
          { model = "opencode-go/glm-5.2"; }
          { model = "opencode-go/kimi-k2.7-code"; }
          { model = "opencode-go/qwen3.7-plus"; }
        ];
      };
      artistry = {
        model = "opencode-go/kimi-k3";
        variant = "xhigh";
        fallback_models = [
          { model = "opencode-go/glm-5.2"; }
        ];
      };
      quick = {
        model = "opencode-go/minimax-m2.7";
        fallback_models = [
          { model = "openai/gpt-5.4-mini-fast"; }
          { model = "opencode-go/minimax-m3"; }
        ];
      };
      unspecified-low = {
        model = "opencode-go/kimi-k2.7-code";
        fallback_models = [
          { model = "opencode-go/minimax-m3"; }
          { model = "opencode-go/minimax-m2.7"; }
        ];
      };
      unspecified-high = {
        model = "opencode-go/kimi-k3";
        fallback_models = [
          {
            model = "openai/gpt-5.6-sol";
            variant = "high";
          }
          { model = "opencode-go/glm-5.2"; }
        ];
      };
      writing = {
        model = "opencode-go/kimi-k3";
        variant = "low";
        fallback_models = [
          { model = "openai/gpt-5.6-luna"; }
          { model = "opencode-go/glm-5.2"; }
        ];
      };
    };
  };
in
{
  xdg.configFile."opencode/opencode.jsonc".text = builtins.toJSON {
    enabled_providers = [ "openai" ] ++ lib.optionals useOpencodeGo [ "opencode-go" ];

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
