# Private declarative Hermes providers

Emilia reads `hermes/providers` from `secrets/shared.yaml` in the private SOPS
repository, alongside `hermes/env-file` and `hermes/cron-jobs`. Add this key
before deploying the configuration. Its decrypted value is a **multiline JSON
string**, just like cron jobs:

```yaml
hermes:
    providers: |
      [
        {
          "provider": "openai-codex",
          "model": "gpt-6-luna",
          "id": "codex-primary",
          "tokens": {
            "access_token": "REPLACE_WITH_OAUTH_ACCESS_TOKEN",
            "refresh_token": "REPLACE_WITH_OAUTH_REFRESH_TOKEN"
          }
        },
        {
          "provider": "opencode-go",
          "model": "qwen3.7-plus",
          "id": "go-primary",
          "api_key": "REPLACE_WITH_OPENCODE_GO_KEY"
        },
        {
          "provider": "zai",
          "model": "glm-5.2",
          "id": "zai-primary",
          "api_key": "REPLACE_WITH_ZAI_KEY",
          "base_url": "https://api.z.ai/api/coding/paas/v4"
        }
      ]
```

Encrypt the value with SOPS before committing. No provider list, model choices,
API keys or OAuth tokens are evaluated by Nix or copied into the Nix store.
Move provider API keys out of `hermes/env-file`; keep Matrix and integration
credentials there. The provider list overrides legacy OpenCode Go and Z.AI
environment keys in the rendered `.env`.

The list must contain at least one entry, with no duplicate providers. Supported
IDs are `openai-codex`, `opencode-go` and `zai`. The **first entry** selects the
global provider and model; reorder the list to change it. In the example above,
the global choice is `openai-codex` / `gpt-6-luna`. For a Codex default of
`gpt-6.1-sol`, put that model on the first entry. To use `opencode-go` /
`qwen3.7-plus` globally instead, move its entire entry to the top. Restart the
gateway and backend after changing the secret (configure `restartUnits` for
both services when both are enabled).

The reconciler writes the first entry to `model.provider` and `model.default`
in the runtime `config.yaml` at service startup and after NixOS activation
installs the configuration. Cron jobs created by
`cronJobsFile` have no model pin and use this global choice, provided there is
no separate `cron.model` / `cron.model_provider` override in the Hermes config.
Existing jobs with interactive model, provider or endpoint overrides retain
them. `hermes cron edit <job-id> --unpin` clears model and provider pins;
it does not clear a separate endpoint override.
See [cron jobs](hermes-cron-jobs.md) for details.

Every entry requires
a stable credential `id`, an unprefixed native model ID and credentials. This
`id` becomes the entry ID inside `credential_pool[provider]` for all providers.
Use existing pool IDs when adopting runtime credentials. An optional HTTPS
`base_url` applies to every provider. Other entries make credentials
available for explicit provider/model selections; this does not configure
automatic failover. Remove an entry to remove that provider's credentials.
These three providers are exclusively managed by this list, including existing
interactive credential-pool entries; unrelated providers are preserved.

API-key entries require `api_key` and optionally accept an HTTPS `base_url`.
Without it Hermes uses its native provider endpoint selection. For Z.AI, choose
the endpoint appropriate to your subscription (the example uses the coding
plan). Codex requires `tokens.access_token` and `tokens.refresh_token`;
`last_refresh` is optional. The credential `id` is separate from the OAuth
tokens. An API key cannot authenticate the `openai-codex` provider.

The private declaration above is converted into Hermes's native auth store:
`providers` stays empty for these managed providers, and each provider gets one
entry in `credential_pool`. API-key entries have `auth_type="api_key"`, an
`env:...` source and a `secret_fingerprint`; their raw keys stay in `.env`.
Codex entries have `auth_type="oauth"`, `source="manual:device_code"` and the
access/refresh tokens directly on the pool entry. Hermes supplies the status,
error and request-counter fields through its native credential serializer.

Obtain a **dedicated Hermes OAuth session** using `hermes auth add openai-codex`
in an isolated `HERMES_HOME`, completing a fresh login rather than importing
another CLI's session. Read its pool entry from `auth.json` with:

```sh
hermes_home=$(systemctl show hermes-agent -p Environment --value |
  tr ' ' '\n' | sed -n 's/^HERMES_HOME=//p')
sudo -u hermes jq '.credential_pool["openai-codex"][0] | {access_token, refresh_token, id}' "$hermes_home/auth.json"
```

The command reads the service's configured `HERMES_HOME`. For an isolated login,
use that login's `HERMES_HOME` instead. Copy `id` into the declaration's `id`
and the access/refresh pair into `tokens`. Stop using the source session after
transferring it: refresh tokens rotate and must not be shared between
independently running agents. Provisioning credentials still requires
a real login; Nix cannot create an OAuth grant.

After NixOS activation installs `config.yaml`, and before each gateway or
backend start, the entire list is validated, credentials
are reconciled into `credential_pool` for all three providers, and
`config.yaml`'s model routing is updated. Malformed declarations or missing
credential fields prevent startup; validation errors omit private values. Token
validity is checked by the provider when Hermes uses it. Files are written
atomically with mode `0600`, using Hermes's auth-store lock to serialize startup
and token refresh writes.

An existing Codex pool entry with the declared `id` is adopted on first use,
preserving its current token pair. After adoption, Codex credentials are seeded
only when the declared token object changes or runtime credentials are missing.
Old singleton state is migrated and removed so Hermes cannot seed a duplicate
`device_code` entry for the same grant. Normal refreshes survive restarts and
rebuilds; unchanged SOPS tokens never replace the refreshed token pair. Publish a new
dedicated grant to SOPS to replace a session. Restoring old SOPS tokens after
losing runtime state can require a new login.

For another host, declare:

```nix
sops.secrets."hermes/providers" = {
  sopsFile = "${my-secrets}/secrets/shared.yaml";
  owner = config.services.hermes-agent.user;
  group = config.services.hermes-agent.group;
  mode = "0400";
  restartUnits = [ "hermes-agent.service" ];
  # Include hermes-backend.service here when enabling the backend.
};
homelab.services.hermes-agent.providersFile =
  config.sops.secrets."hermes/providers".path;
```

Native service mode is required. Do not combine `providersFile` with upstream
`authFile`, or model routing fields in `settings.model`. The module rejects
these combinations. If using `configFile`, remove model routing fields there
as well: reconciliation replaces them after activation and at startup. Keep
tuning such as reasoning settings in the active configuration source (`settings`
or `configFile`). Unsetting `providersFile` stops reconciliation without removing
runtime credentials; subsequent activations still apply `settings` or
`configFile`. Verify the reconciler against the pinned Hermes auth API when
upgrading the flake input.

Older versions only reconciled providers at service startup. With `configFile`,
an otherwise unrelated rebuild could replace the runtime config without
restarting Hermes, erasing `model.default` and causing cron's "no model
configured" error. Restart both services to restore routing immediately:

```sh
sudo systemctl restart hermes-agent hermes-backend
```

Omit `hermes-backend` when it is disabled. Deploy the activation hook in this
module to preserve the global model across subsequent rebuilds. Run the provider
regression tests with the pinned package's `hermesVenv/bin/python3`:

```sh
python3 modules/homelab/services/hermes-agent/test-providers.py
```
