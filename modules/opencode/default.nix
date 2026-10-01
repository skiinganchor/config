{ lib, osConfig ? { }, ... }:
let
  useOpencodeGo = lib.attrByPath [ "homelab" "opencode" "useOpencodeGo" ] false osConfig;

  defaultModelConfig = {
    # ChatGPT Plus models authenticated through OpenCode's OpenAI provider.
    categories = {
      quick = {
        model = "openai/gpt-6-luna";
        variant = "low";
      };
      visual-engineering = {
        model = "openai/gpt-6-astra";
        variant = "medium";
      };
      ultrabrain = {
        model = "openai/gpt-6-astra";
        variant = "xhigh";
      };
      deep = {
        model = "openai/gpt-6-astra";
        variant = "high";
      };
      artistry = {
        model = "openai/gpt-6-astra";
        variant = "medium";
      };
      unspecified-low = {
        model = "openai/gpt-6-luna";
        variant = "low";
      };
      unspecified-high = {
        model = "openai/gpt-6-astra";
        variant = "high";
      };
      writing = {
        model = "openai/gpt-6-astra";
        variant = "medium";
      };
    };

    # Agent-specific model overrides
    agents = {
      sisyphus = {
        model = "openai/gpt-6-astra";
        variant = "medium";
      };
      oracle = {
        model = "openai/gpt-6-astra";
        variant = "high";
      };
      librarian = {
        model = "openai/gpt-6-luna";
        variant = "low";
      };
      explore = {
        model = "openai/gpt-6-luna";
        variant = "low";
      };
      "multimodal-looker" = {
        model = "openai/gpt-6-astra";
        variant = "medium";
      };
      hephaestus = {
        model = "openai/gpt-6.1-sol";
        variant = "medium";
      };
      prometheus = {
        model = "openai/gpt-6-astra";
        variant = "high";
      };
      metis = {
        model = "openai/gpt-6-astra";
        variant = "high";
      };
      momus = {
        model = "openai/gpt-6-astra";
        variant = "xhigh";
      };
      atlas = {
        model = "openai/gpt-6.1-sol";
        variant = "medium";
      };
      "sisyphus-junior" = {
        model = "openai/gpt-6.1-sol";
        variant = "medium";
      };
    };
  };

  opencodeGoModelConfig = {
    agents = {
      sisyphus = {
        model = "opencode-go/kimi-k3";
        fallback_models = [
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "medium";
          }
          {
            model = "opencode-go/glm-5.3";
            reasoning = "high";
          }
        ];
      };
      hephaestus = {
        model = "openai/gpt-6.1-sol";
        variant = "medium";
        fallback_models = [
          { model = "opencode-go/kimi-k2.7-code"; }
          {
            model = "opencode-go/glm-5.3";
            reasoning = "high";
          }
        ];
      };
      oracle = {
        model = "openai/gpt-6.1-sol";
        variant = "high";
        fallback_models = [
          {
            model = "opencode-go/glm-5.3";
            reasoning = "max";
          }
          {
            model = "openai/gpt-6-astra";
            reasoning = "high";
          }
        ];
      };
      librarian = {
        model = "opencode-go/gpt-6-luna";
        variant = "low";
        fallback_models = [
          {
            model = "opencode-go/deepseek-v4.1-flash";
            reasoning = "low";
          }
          {
            model = "opencode-go/qwen3.8-flash";
            reasoning = "low";
          }
        ];
      };
      explore = {
        model = "opencode-go/qwen3.8-flash";
        variant = "low";
        fallback_models = [
          {
            model = "opencode-go/gpt-6-luna";
            reasoning = "low";
          }
          {
            model = "opencode-go/deepseek-v4.1-flash";
            reasoning = "low";
          }
        ];
      };
      "multimodal-looker" = {
        model = "openai/gpt-6.1-sol";
        variant = "medium";
        fallback_models = [
          { model = "opencode-go/kimi-k3"; }
          {
            model = "opencode-go/qwen3.8-max";
            reasoning = "medium";
          }
          {
            model = "opencode-go/glm-5.3-flash";
            reasoning = "high";
          }
        ];
      };
      prometheus = {
        model = "opencode-go/kimi-k3";
        variant = "high";
        fallback_models = [
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "high";
          }
          {
            model = "opencode-go/qwen3.8-max";
            reasoning = "medium";
          }
        ];
      };
      metis = {
        model = "opencode-go/kimi-k3";
        variant = "low";
        fallback_models = [
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "high";
          }
          {
            model = "opencode-go/glm-5.3";
            reasoning = "high";
          }
        ];
      };
      momus = {
        model = "openai/gpt-6-astra";
        variant = "xhigh";
        fallback_models = [
          {
            model = "opencode-go/glm-5.3";
            reasoning = "max";
          }
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "xhigh";
          }
        ];
      };
      atlas = {
        model = "opencode-go/kimi-k3";
        fallback_models = [
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "medium";
          }
          { model = "opencode-go/kimi-k2.7-code"; }
        ];
      };
      "sisyphus-junior" = {
        model = "opencode-go/kimi-k2.7-code";
        fallback_models = [
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "medium";
          }
          {
            model = "opencode-go/glm-5.3";
            reasoning = "high";
          }
        ];
      };
    };

    categories = {
      visual-engineering = {
        model = "opencode-go/kimi-k3";
        variant = "high";
        fallback_models = [
          {
            model = "openai/gpt-6.1-sol";
            variant = "medium";
          }
          {
            model = "opencode-go/qwen3.8-max";
            reasoning = "medium";
          }
        ];
      };
      ultrabrain = {
        model = "openai/gpt-6-astra";
        variant = "xhigh";
        fallback_models = [
          {
            model = "opencode-go/glm-5.3";
            reasoning = "max";
          }
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "xhigh";
          }
        ];
      };
      deep = {
        model = "openai/gpt-6-astra";
        variant = "high";
        fallback_models = [
          { model = "opencode-go/kimi-k3"; }
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "medium";
          }
        ];
      };
      artistry = {
        model = "opencode-go/kimi-k3";
        variant = "high";
        fallback_models = [
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "medium";
          }
          {
            model = "opencode-go/qwen3.8-max";
            reasoning = "xhigh";
          }
          {
            model = "opencode-go/grok-4.6";
            reasoning = "high";
          }
        ];
      };
      quick = {
        model = "opencode-go/qwen3.8-flash";
        variant = "low";
        fallback_models = [
          {
            model = "opencode-go/gpt-6-luna";
            reasoning = "low";
          }
          {
            model = "opencode-go/deepseek-v4.1-flash";
            reasoning = "low";
          }
        ];
      };
      unspecified-low = {
        model = "opencode-go/qwen3.8-flash";
        variant = "medium";
        fallback_models = [
          {
            model = "opencode-go/gpt-6-luna";
            reasoning = "low";
          }
          { model = "opencode-go/minimax-m3"; }
        ];
      };
      unspecified-high = {
        model = "openai/gpt-6-astra";
        variant = "high";
        fallback_models = [
          { model = "opencode-go/kimi-k3"; }
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "medium";
          }
        ];
      };
      writing = {
        model = "opencode-go/kimi-k3";
        variant = "low";
        fallback_models = [
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "medium";
          }
          {
            model = "opencode-go/qwen3.8-max";
            reasoning = "medium";
          }
          {
            model = "opencode-go/mimo-v2.5-pro";
            reasoning = "high";
          }
        ];
      };
    };
  };
in
{
  xdg.configFile."opencode/opencode.jsonc".text = builtins.toJSON {
    enabled_providers = [ "openai" ] ++ lib.optionals useOpencodeGo [ "opencode-go" ];

    plugin = [
      "oh-my-openagent@5.1.7"
      "@cortexkit/opencode-openai-auth@0.11.0"
    ];
  };

  home.file.".omo/omo.jsonc".text = builtins.toJSON {
    "[opencode]" = {
      disabled_hooks = [
        "claude-code-hooks"
      ];
    } // (if useOpencodeGo then opencodeGoModelConfig else defaultModelConfig);
  };
}
