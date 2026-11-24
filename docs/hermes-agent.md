# Hermes Agent profiles

The Hermes input tracks the upstream default branch. NixOS manages accounts, services, and runtime dependencies. The private `my-secrets` flake supplies encrypted Hermes files. A profile has its own account, home, workspace, credentials, conversations, and scheduler state.

## Update Hermes

The scheduled lockfile workflow updates Hermes along with the other inputs and builds the proposed Hermes revision before merging. To refresh only Hermes locally, run `nix flake update hermes-agent`. A rebuild installs the revision recorded in `flake.lock`. Compare the upstream commit in the profile launcher's `--version` output with that lock entry. Upstream Nix builds can display `0.0.0` alongside the exact commit.

The Hermes CLI runs in NixOS-managed mode and directs `hermes update` to the package manager. This bypasses the source updater and its `uv sync --locked` failure described in [issue #125922](https://github.com/NousResearch/hermes-agent/issues/125922).

The separate [PR #141957](https://github.com/NousResearch/hermes-agent/pull/141957) addresses false missing-tool warnings when Hermes sees PM receipts on a Nix installation.

## Configure a host

Set `enable`, `addToSystemPackages`, and `backend` under `homelab.services.hermes-agent` in the machine module. Point `profilesFile` to its SOPS-encrypted YAML file in `config-private`. The backend uses the only profile when there is one. With several profiles, the backend uses the reserved default profile. Other profiles get independent gateways and state.

In the SOPS editor, put the profile records under `hermes` → `profiles` and use the chosen profile ID as the key for each record. Nix reads the keys of the encrypted YAML to generate the accounts, systemd units, and SOPS entries. sops-nix decrypts the individual values at activation. Keep service switches, listener addresses, and ports in Nix.

| Field | Value |
| --- | --- |
| `model` | Optional shared YAML routing string on the default profile |
| `config` | Complete native `config.yaml` as a string |
| `env` | Complete native dotenv file as a string |
| `auth` | Optional native `auth.json` first-use seed |
| `cron` | Optional native cron definitions as a JSON string |
| `garmin` | Optional native Garmin token JSON as a string |
| `skills` | Optional base64-encoded tar archive of the managed skills tree |
| `legacyProviders`, `legacySkills` | Optional compatibility strings for older private inputs |

Run `sops edit` on the profile file in `config-private`. After publishing a private change, run `nix flake update my-secrets` before rebuilding. Refresh the deployment wrapper's `cfg` input if it consumes the public flake separately. The profile file must be present in the locked private revision for an enabled host. A missing file stops evaluation before any running unit is replaced.

The public repository carries the schema only. Generated account names, unit names, and SOPS key paths are visible on the deployed host.

## Native configuration

Hermes uses the native model selection and credential discovery. Use `OPENCODE_GO_BASE_URL` or `GLM_BASE_URL` when overriding the corresponding provider endpoint. Z.AI keys can use `GLM_API_KEY`. `fallback_providers` belongs in `config.yaml` when automatic fallback is desired. Matrix account tokens, sender and room allowlists, and E2EE settings belong in the profile's `.env`. Give each gateway its own messaging identity and each Nextcloud user its own app password.

For dashboard passwords, use `hermes dashboard password` in a scratch profile to create the hash and signing secret, then transfer the native YAML through the SOPS editor. For profiles reached over a network, preserve Hermes authentication, restrict listener access, and use HTTPS for transport privacy.

SOPS files are delivered to the profile owner with mode `0400`. NixOS loads them at service start and restarts the consuming units on changes. The profile home is `0700` and prepared files are `0600`. Bind addresses, ports, SOPS key names, and profile IDs can appear in the evaluated Nix store and systemd units on the host. Hermes needs readable plaintext at runtime, including its writable credentials, logs, and scheduler state. Protect backups of the state directory accordingly. Systemd records service state and redacted preparation failures. Process output is under the profile's `logs/` directory, including `hermes-agent*.service.log` and `hermes-backend*.service.log`.

- [Hermes configuration](https://hermes-agent.nousresearch.com/docs/user-guide/configuration)
- [Provider credentials](https://hermes-agent.nousresearch.com/docs/integrations/providers)
- [Model routing](https://hermes-agent.nousresearch.com/docs/user-guide/configuring-models)
- [Dashboard](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard)
- [MCP configuration](https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp)

### Nextcloud Context Agent

On a Nextcloud host, enable the shared MCP endpoint with `homelab.services.nextcloud.contextAgent.enable`. Check registration with `sudo nextcloud-occ app_api:app:list` and `systemctl status nextcloud-context-agent-register`. Each profile connects with its own Nextcloud app password. Verify access by listing files or calendars.

## OAuth and Garmin

Hermes owns the writable `auth.json`. Run `auth add openai-codex` through the profile's CLI launcher for a new independent grant. An optional `auth` field contains a native `auth.json` exported from an isolated Hermes login and seeds an absent runtime file. Stop using the source session after transfer. A rotating refresh token must belong to one running profile, and a normal profile restart keeps the live credential. Use Hermes's auth commands for  deliberate OAuth replacement.

To enable Garmin, set `garmin.enable = true` in Nix and add the native MCP entry to its encrypted config:

```yaml
mcp_servers:
  garmin:
    command: garmin-mcp
    connect_timeout: 180
```

The module supplies the pinned Garmin MCP and authentication launchers. Their first invocation downloads the pinned Git source and its runtime dependencies. If supplied, the private `garmin` field holds the complete `garmin_tokens.json` object. An existing runtime token is adopted on first use. Later SOPS changes replace it, while an unchanged seed lets the live token refresh. The token file is in `.garminconnect` under the profile's state directory. To refresh it interactively, stop both profile units, then run `garmin-mcp-auth --force-reauth` followed by `garmin-mcp-auth --verify` as the profile account with its `HERMES_HOME`.

## Managed skills

Put ordinary native `SKILL.md` directories and their companion files in a tar archive. Use executable mode for scripts that need it. Base64-encode the archive and enter the result as the private `skills` string in the SOPS editor. Hermes discovers the published tree through the encrypted `config.yaml`:

```yaml
skills:
  external_dirs:
    - managed-skills
```

This path is relative to the profile's `HERMES_HOME`. The module publishes a complete tree when the archive changes. Use unique skill names because Hermes prioritizes locally installed skills on collisions. An empty archive publishes an empty managed directory. To stop managing skills entirely, remove the `skills` field and its `external_dirs` entry. The last private runtime tree remains on disk.

## Managed cron jobs

Set the private `cron` value to a JSON string with a native `jobs` list. Keep IDs stable and use Hermes recurring schedules such as `0 9 * * *` or `every 2h`.

```json
{
  "jobs": [
    {
      "id": "morning-summary",
      "name": "Morning summary",
      "schedule": "0 9 * * *",
      "deliver": "matrix:!room-id:example.org",
      "prompt": "Prepare my morning summary.",
      "skills": ["morning-briefing"]
    }
  ]
}
```

The gateway updates managed definitions using the Hermes cron store and lock. Unchanged schedules retain their next run and existing jobs keep their runtime IDs and history. `enabled` is an optional declaration override. Omit it to preserve an existing pause. Existing interactive jobs remain in the store. To remove all managed definitions, apply `{"jobs": []}` before removing the key. Jobs can pin a provider or inherit `cron.model` and `cron.model_provider` from `config.yaml`, with the main profile model as the default. The gateway account has lingering enabled for Hermes's restart-safe cron workers. [Hermes cron](https://hermes-agent.nousresearch.com/docs/user-guide/features/cron)

## Example with a shared model

Edit the YAML file named by the machine's `profilesFile` setting. In `config-private`, open `secrets/hermes-emilia.yaml` with SOPS. Keep your existing values and add profiles as needed.

```yaml
hermes:
  profiles:
    default:
      model: |
        provider: openrouter
        default: REPLACE_WITH_MODEL_ID
      config: |
        timezone: Europe/Amsterdam
      env: |
        OPENROUTER_API_KEY=REPLACE_WITH_DEFAULT_PROFILE_KEY
    coder:
      config: |
        timezone: Europe/Amsterdam
      env: |
        OPENROUTER_API_KEY=REPLACE_WITH_CODER_PROFILE_KEY
```

The `model`, `config`, and `env` fields are multiline strings. A profile inherits the shared provider and model when its native config omits `model`. Set `model` in a profile's native config to override the shared routing. The shared field accepts `provider` and `default`. Each profile supplies its own credentials.
