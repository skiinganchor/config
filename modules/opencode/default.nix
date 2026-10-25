{ config, lib, osConfig, pkgs ? { }, ... }:
let
  useOpencodeGo = lib.attrByPath [ "homelab" "opencode" "useOpencodeGo" ] false osConfig;
  omoVersion = "5.1.47";
  omoPlugin = "oh-my-openagent@${omoVersion}";
  openaiAuthPlugin = "@cortexkit/opencode-openai-auth@1.5.0";

  openaiModelConfig = {
    agents = {
      sisyphus = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          { model = "openai/gpt-6-sol"; reasoning = "medium"; }
          { model = "openai/gpt-6-astra"; reasoning = "high"; }
        ];
      };
      hephaestus = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          { model = "openai/gpt-6-sol"; reasoning = "medium"; }
          { model = "openai/gpt-6-astra"; reasoning = "high"; }
        ];
      };
      oracle = {
        model = "openai/gpt-6.1-sol";
        reasoning = "high";
        fallback_models = [
          { model = "openai/gpt-6-sol"; reasoning = "high"; }
          { model = "openai/gpt-6-astra"; reasoning = "high"; }
        ];
      };
      librarian = {
        model = "openai/gpt-6-luna";
        reasoning = "low";
        fallback_models = [
          { model = "openai/gpt-6-sol"; reasoning = "low"; }
          { model = "openai/gpt-6.1-sol"; reasoning = "low"; }
        ];
      };
      explore = {
        model = "openai/gpt-6-luna";
        reasoning = "low";
        fallback_models = [
          { model = "openai/gpt-6-sol"; reasoning = "low"; }
          { model = "openai/gpt-6.1-sol"; reasoning = "low"; }
        ];
      };
      "multimodal-looker" = {
        model = "openai/gpt-6-luna";
        reasoning = "low";
        fallback_models = [
          { model = "openai/gpt-6.1-sol"; reasoning = "medium"; }
          { model = "openai/gpt-6-astra"; reasoning = "medium"; }
        ];
      };
      prometheus = {
        model = "openai/gpt-6.1-sol";
        reasoning = "high";
        fallback_models = [
          { model = "openai/gpt-6-astra"; reasoning = "high"; }
          { model = "openai/gpt-6-sol"; reasoning = "high"; }
        ];
      };
      metis = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          { model = "openai/gpt-6-sol"; reasoning = "medium"; }
          { model = "openai/gpt-6-luna"; reasoning = "medium"; }
        ];
      };
      momus = {
        model = "openai/gpt-6.1-sol";
        reasoning = "high";
        fallback_models = [
          { model = "openai/gpt-6-astra"; reasoning = "high"; }
          { model = "openai/gpt-6-sol"; reasoning = "high"; }
        ];
      };
      atlas = {
        model = "openai/gpt-6-luna";
        reasoning = "medium";
        fallback_models = [
          { model = "openai/gpt-6.1-sol"; reasoning = "medium"; }
          { model = "openai/gpt-6-sol"; reasoning = "medium"; }
        ];
      };
      "sisyphus-junior" = {
        model = "openai/gpt-6-sol";
        reasoning = "low";
        fallback_models = [
          { model = "openai/gpt-6-luna"; reasoning = "low"; }
          { model = "openai/gpt-6.1-sol"; reasoning = "medium"; }
        ];
      };
    };

    categories = {
      visual-engineering = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          { model = "openai/gpt-6-sol"; reasoning = "medium"; }
          { model = "openai/gpt-6-astra"; reasoning = "medium"; }
        ];
      };
      ultrabrain = {
        model = "openai/gpt-6.1-sol";
        reasoning = "high";
        fallback_models = [
          { model = "openai/gpt-6-astra"; reasoning = "high"; }
          { model = "openai/gpt-6-sol"; reasoning = "high"; }
        ];
      };
      deep = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          { model = "openai/gpt-6-sol"; reasoning = "medium"; }
          { model = "openai/gpt-6-astra"; reasoning = "high"; }
        ];
      };
      artistry = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          { model = "openai/gpt-6-sol"; reasoning = "medium"; }
          { model = "openai/gpt-6-luna"; reasoning = "medium"; }
        ];
      };
      quick = {
        model = "openai/gpt-6-luna";
        reasoning = "low";
        fallback_models = [
          { model = "openai/gpt-6-sol"; reasoning = "low"; }
          { model = "openai/gpt-6.1-sol"; reasoning = "low"; }
        ];
      };
      unspecified-low = {
        model = "openai/gpt-6-luna";
        reasoning = "medium";
        fallback_models = [
          { model = "openai/gpt-6-sol"; reasoning = "medium"; }
          { model = "openai/gpt-6.1-sol"; reasoning = "medium"; }
        ];
      };
      unspecified-high = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          { model = "openai/gpt-6-sol"; reasoning = "high"; }
          { model = "openai/gpt-6-astra"; reasoning = "high"; }
        ];
      };
      writing = {
        model = "openai/gpt-6-luna";
        reasoning = "low";
        fallback_models = [
          { model = "openai/gpt-6.1-sol"; reasoning = "low"; }
          { model = "openai/gpt-6-sol"; reasoning = "low"; }
        ];
      };
    };
  };

  opencodeGoModelConfig = {
    agents = {
      sisyphus = {
        model = "opencode-go/kimi-k2.7-code";
        reasoning = "medium";
        fallback_models = [
          { model = "opencode-go/minimax-m3"; }
          { model = "openai/gpt-6.1-sol"; reasoning = "medium"; }
        ];
      };
      hephaestus = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          { model = "opencode-go/kimi-k2.7-code"; }
          { model = "opencode-go/deepseek-v4.1-flash"; }
        ];
      };
      oracle = {
        model = "openai/gpt-6.1-sol";
        reasoning = "high";
        fallback_models = [
          {
            model = "openai/gpt-6-sol";
            reasoning = "high";
          }
          {
            model = "opencode-go/glm-5.2";
            reasoning = "high";
          }
        ];
      };
      librarian = {
        model = "opencode-go/mimo-v2.6-flash";
        reasoning = "low";
        fallback_models = [
          {
            model = "opencode-go/deepseek-v4.1-flash";
            reasoning = "low";
          }
          {
            model = "opencode-go/longcat-2.5-preview-free";
            reasoning = "low";
          }
        ];
      };
      explore = {
        model = "opencode-go/deepseek-v4.1-flash";
        reasoning = "low";
        fallback_models = [
          {
            model = "opencode-go/mimo-v2.6-flash";
            reasoning = "low";
          }
          {
            model = "opencode-go/longcat-2.5-preview-free";
            reasoning = "low";
          }
        ];
      };
      "multimodal-looker" = {
        model = "opencode-go/deepseek-v4-flash-vision-exp";
        reasoning = "medium";
        fallback_models = [
          {
            model = "opencode-go/gpt-6-luna";
            reasoning = "low";
          }
          { model = "openai/gpt-6.1-sol"; reasoning = "medium"; }
        ];
      };
      prometheus = {
        model = "openai/gpt-6.1-sol";
        reasoning = "high";
        fallback_models = [
          {
            model = "opencode-go/glm-5.2";
            reasoning = "high";
          }
          {
            model = "opencode-go/deepseek-v4-pro";
          }
        ];
      };
      metis = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          {
            model = "opencode-go/deepseek-v4-pro";
          }
          {
            model = "opencode-go/minimax-m3";
          }
        ];
      };
      momus = {
        model = "openai/gpt-6.1-sol";
        reasoning = "high";
        fallback_models = [
          {
            model = "openai/gpt-6-astra";
            reasoning = "high";
          }
          {
            model = "opencode-go/glm-5.2";
            reasoning = "high";
          }
        ];
      };
      atlas = {
        model = "opencode-go/gpt-6-luna";
        reasoning = "medium";
        fallback_models = [
          { model = "openai/gpt-6.1-sol"; reasoning = "medium"; }
          { model = "opencode-go/deepseek-v4.1-flash"; }
        ];
      };
      "sisyphus-junior" = {
        model = "opencode-go/deepseek-v4.1-flash";
        reasoning = "low";
        fallback_models = [
          { model = "opencode-go/kimi-k2.7-code"; }
          { model = "openai/gpt-6.1-sol"; reasoning = "medium"; }
        ];
      };
    };

    categories = {
      visual-engineering = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          { model = "opencode-go/deepseek-v4.1-flash"; }
          { model = "opencode-go/qwen3.7-plus"; }
        ];
      };
      ultrabrain = {
        model = "openai/gpt-6.1-sol";
        reasoning = "high";
        fallback_models = [
          {
            model = "openai/gpt-6-astra";
            reasoning = "high";
          }
          {
            model = "opencode-go/glm-5.2";
            reasoning = "high";
          }
        ];
      };
      deep = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          { model = "opencode-go/deepseek-v4-pro"; }
          {
            model = "opencode-go/glm-5.2";
            reasoning = "high";
          }
        ];
      };
      artistry = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          { model = "opencode-go/qwen3.7-plus"; }
          { model = "opencode-go/deepseek-v4.1-flash"; }
        ];
      };
      quick = {
        model = "opencode-go/gpt-6-luna";
        reasoning = "low";
        fallback_models = [
          { model = "opencode-go/mimo-v2.6-flash"; reasoning = "low"; }
          { model = "opencode-go/longcat-2.5-preview-free"; }
        ];
      };
      unspecified-low = {
        model = "opencode-go/mimo-v2.6-pro";
        reasoning = "high";
        fallback_models = [
          { model = "opencode-go/gpt-6-luna"; reasoning = "medium"; }
          { model = "opencode-go/deepseek-v4.1-flash"; }
        ];
      };
      unspecified-high = {
        model = "openai/gpt-6.1-sol";
        reasoning = "medium";
        fallback_models = [
          { model = "opencode-go/deepseek-v4-pro"; }
          { model = "opencode-go/glm-5.2"; reasoning = "high"; }
        ];
      };
      writing = {
        model = "opencode-go/qwen3.7-plus";
        reasoning = "low";
        fallback_models = [
          { model = "openai/gpt-6.1-sol"; reasoning = "low"; }
          { model = "opencode-go/mimo-v2.6-pro"; }
        ];
      };
    };
  };
in
{
  xdg.configFile."opencode/opencode.jsonc".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    policies = [
      { action = "provider.use"; resource = "*"; effect = "deny"; }
      { action = "provider.use"; resource = "openai"; effect = "allow"; }
    ] ++ lib.optionals useOpencodeGo [
      { action = "provider.use"; resource = "opencode-go"; effect = "allow"; }
    ];

    plugins = [
      omoPlugin
      openaiAuthPlugin
    ];
  };

  # OpenCode 2 loads TUI plugins from cli.json independently of opencode.jsonc.
  # Keep that mutable file's UI preferences and unrelated plugins, while also
  # updating registrations left in tui.json by the OpenCode 1 installer.
  home.activation.opencodeTuiPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    reconcile_tui_plugins() {
      local path="$1" key="$2" temporary
      temporary=$(${pkgs.coreutils}/bin/mktemp)
      ${pkgs.jq}/bin/jq --arg key "$key" --arg plugin ${lib.escapeShellArg omoPlugin} '
        .[$key] = (
          [(.[$key] // [])[] | select(
            (if type == "object" then .package else . end)
            | test("^oh-my-(openagent|opencode)(@|/|$)") | not
          )]
          + [$plugin]
        )
      ' "$path" > "$temporary" || { ${pkgs.coreutils}/bin/rm -- "$temporary"; return 1; }
      run ${pkgs.coreutils}/bin/install -m 0600 -- "$temporary" "$path"
      ${pkgs.coreutils}/bin/rm -- "$temporary"
    }

    opencode_config_dir=${lib.escapeShellArg "${config.xdg.configHome}/opencode"}
    run ${pkgs.coreutils}/bin/mkdir -p -- "$opencode_config_dir"
    if [[ -e "$opencode_config_dir/cli.json" ]]; then
      reconcile_tui_plugins "$opencode_config_dir/cli.json" plugins
    else
      run ${pkgs.coreutils}/bin/install -m 0600 -- ${pkgs.writeText "opencode-cli.json" (builtins.toJSON {
        "$schema" = "https://opencode.ai/v2/cli.json";
        plugins = [ omoPlugin ];
      })} "$opencode_config_dir/cli.json"
    fi
    if [[ -e "$opencode_config_dir/tui.json" ]]; then
      reconcile_tui_plugins "$opencode_config_dir/tui.json" plugin
    fi
  '';

  home.activation.omoConfig =
    let
      omoConfig = pkgs.writeText "omo.jsonc"
        (
          builtins.toJSON {
            "$schema" =
              "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/v${omoVersion}/assets/omo.schema.json";
            "[opencode]" = {
              disabled_hooks = [
                "claude-code-hooks"
              ];
            } // (if useOpencodeGo then opencodeGoModelConfig else openaiModelConfig);
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
