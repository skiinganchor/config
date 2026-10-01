{ config, lib, osConfig, pkgs ? { }, ... }:
let
  useOpencodeGo = lib.attrByPath [ "homelab" "opencode" "useOpencodeGo" ] false osConfig;

  defaultModelConfig = {
    # ChatGPT Plus models authenticated through OpenCode's OpenAI provider.
    categories = {
      quick = {
        model = "openai/gpt-6-luna";
        reasoning = "low";
      };
      visual-engineering = {
        model = "openai/gpt-6-astra";
        reasoning = "medium";
      };
      ultrabrain = {
        model = "openai/gpt-6-astra";
        reasoning = "xhigh";
      };
      deep = {
        model = "openai/gpt-6-astra";
        reasoning = "high";
      };
      artistry = {
        model = "openai/gpt-6-astra";
        reasoning = "medium";
      };
      unspecified-low = {
        model = "openai/gpt-6-luna";
        reasoning = "low";
      };
      unspecified-high = {
        model = "openai/gpt-6-astra";
        reasoning = "high";
      };
      writing = {
        model = "openai/gpt-6-astra";
        reasoning = "medium";
      };
    };

    # Agent-specific model overrides
    agents = {
      sisyphus = {
        model = "openai/gpt-6-astra";
        reasoning = "medium";
      };
      oracle = {
        model = "openai/gpt-6-astra";
        reasoning = "high";
      };
      librarian = {
        model = "openai/gpt-6-luna";
        reasoning = "low";
      };
      explore = {
        model = "openai/gpt-6-luna";
        reasoning = "low";
      };
      "multimodal-looker" = {
        model = "openai/gpt-6-astra";
        reasoning = "medium";
      };
      hephaestus = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
      };
      prometheus = {
        model = "openai/gpt-6-astra";
        reasoning = "high";
      };
      metis = {
        model = "openai/gpt-6-astra";
        reasoning = "high";
      };
      momus = {
        model = "openai/gpt-6-astra";
        reasoning = "xhigh";
      };
      atlas = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
      };
      "sisyphus-junior" = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
      };
    };
  };

  opencodeGoModelConfig = {
    agents = {
      sisyphus = {
        model = "opencode-go/deepseek-v4.1-flash";
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
        reasoning = "medium";
        fallback_models = [
          { model = "opencode-go/deepseek-v4.1-flash"; }
          {
            model = "opencode-go/glm-5.3";
            reasoning = "high";
          }
        ];
      };
      oracle = {
        model = "openai/gpt-6.1-sol";
        reasoning = "high";
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
        reasoning = "low";
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
        reasoning = "low";
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
        reasoning = "medium";
        fallback_models = [
          { model = "opencode-go/deepseek-v4.1-flash"; }
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
        model = "opencode-go/deepseek-v4.1-flash";
        reasoning = "high";
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
        model = "opencode-go/deepseek-v4.1-flash";
        reasoning = "low";
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
        reasoning = "xhigh";
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
        model = "opencode-go/deepseek-v4.1-flash";
        fallback_models = [
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "medium";
          }
          { model = "opencode-go/deepseek-v4.1-flash"; }
        ];
      };
      "sisyphus-junior" = {
        model = "opencode-go/deepseek-v4.1-flash";
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
        model = "opencode-go/deepseek-v4.1-flash";
        reasoning = "high";
        fallback_models = [
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "medium";
          }
          {
            model = "opencode-go/qwen3.8-max";
            reasoning = "medium";
          }
        ];
      };
      ultrabrain = {
        model = "openai/gpt-6-astra";
        reasoning = "xhigh";
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
        reasoning = "high";
        fallback_models = [
          { model = "opencode-go/deepseek-v4.1-flash"; }
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "medium";
          }
        ];
      };
      artistry = {
        model = "opencode-go/deepseek-v4.1-flash";
        reasoning = "high";
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
        reasoning = "low";
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
        reasoning = "medium";
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
        reasoning = "high";
        fallback_models = [
          { model = "opencode-go/deepseek-v4.1-flash"; }
          {
            model = "openai/gpt-6.1-sol";
            reasoning = "medium";
          }
        ];
      };
      writing = {
        model = "opencode-go/deepseek-v4.1-flash";
        reasoning = "low";
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

  home.activation.omoConfig =
    let
      omoConfig = pkgs.writeText "omo.jsonc"
        (
          builtins.toJSON {
            "$schema" =
              "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/v5.1.7/assets/omo.schema.json";
            "[opencode]" = {
              disabled_hooks = [
                "claude-code-hooks"
              ];
            } // (if useOpencodeGo then opencodeGoModelConfig else defaultModelConfig);
          }
        );
      omoConfigDir = lib.escapeShellArg "${config.home.homeDirectory}/.omo";
      omoConfigPath = lib.escapeShellArg "${config.home.homeDirectory}/.omo/omo.jsonc";
    in
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${pkgs.coreutils}/bin/mkdir -p -- ${omoConfigDir}
      if [[ -L ${omoConfigPath} ]]; then
        run ${pkgs.coreutils}/bin/rm -- ${omoConfigPath}
      fi
      run ${pkgs.coreutils}/bin/install -m 0600 -- ${omoConfig} ${omoConfigPath}
    '';
}
