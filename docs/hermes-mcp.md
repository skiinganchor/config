# Hermes MCP integrations

## Nextcloud Context Agent: one endpoint, per-user access

emilia enables `homelab.services.nextcloud.contextAgent.enable`. This provisions
[Nextcloud's official Context Agent](https://docs.nextcloud.com/server/stable/admin_manual/ai/app_context_agent.html)
2.9.1 as an OCI container and enables the AppAPI app shipped with Nextcloud 35.
A systemd service registers the backend using AppAPI's `manual-install` method;
Nix manages the container. No Docker socket or separate public MCP port is needed.
The backend binds to `127.0.0.1:9031`; Nextcloud handles HTTPS, authentication,
and proxying at:

```text
https://cloud.example.com/index.php/apps/app_api/proxy/context_agent/mcp/
```

emilia also enables `homelab.services.hermes-agent.mcp.nextcloud.enable`. This
declares the remote `nextcloud` server using the configured Nextcloud hostname and a literal
`${NEXTCLOUD_APP_PASSWORD}` reference. The password is resolved at runtime.
The module installs this definition even when a private `configFile` is used;
see [dashboard authentication](hermes-dashboard-auth.md). Nix definitions replace
secret entries with the same server names; other private servers are preserved.
On other hosts, enable the same option and override `mcp.nextcloud.url` if needed.

This is one shared server for all users. Each request authenticates the Nextcloud
user from its app password, and tools act with that user's access. For additional
Hermes profiles, add the following to each profile's `config.yaml`, replacing
`cloud.example.com` with the configured Nextcloud hostname:

```yaml
mcp_servers:
  nextcloud:
    url: "https://cloud.example.com/index.php/apps/app_api/proxy/context_agent/mcp/"
    headers:
      Authorization: "Bearer ${NEXTCLOUD_APP_PASSWORD}"
```

Create a separate app password for each user in Nextcloud's personal security
settings. Put `NEXTCLOUD_APP_PASSWORD` in that Hermes profile's private runtime
environment (`.env`), not in Nix or a shared profile's configuration. For a single
service profile on emilia, add the variable to the existing private SOPS
`hermes/env-file` before restarting Hermes:

```dotenv
NEXTCLOUD_APP_PASSWORD=your-nextcloud-app-password
```

Do not reuse one user's credential for other users' profiles. Profile isolation
is separate from routing multiple chat users into a single Hermes profile.

Context Agent exposes tools for the installed Nextcloud apps, including files,
calendars, contacts, and tasks. Enable or disable tool groups in Nextcloud's AI
administration settings. MCP-only use needs no text-generation provider or
Nextcloud Assistant UI. Available operations differ from dav-mcp; verify the
tools your workflows need after deployment.

The backend's internal `APP_SECRET` is generated once under
`/var/lib/nextcloud-context-agent/secret.env`, outside the Nix store. This is
separate from users' app passwords. Back up this directory and the container's
`nextcloud-context-agent-data` volume alongside Nextcloud's database. Keep the
internal secret and AppAPI registration together when restoring a backup.
Update the pinned version and route metadata in `nextcloud/context-agent.nix`
together. Use Nix rebuilds for backend updates; AppAPI's manual deployment does
not manage the container image.

After rebuilding emilia, check:

```sh
sudo systemctl status nextcloud-context-agent-register
sudo nextcloud-occ app_api:app:list
sudo journalctl -u nextcloud-context-agent-register
```

Expect `context_agent` to be enabled. In two Hermes profiles with different
Nextcloud users' app passwords, discover tools and list files or calendars;
verify that each sees only its own accessible data. Also check that a missing or
invalid password is rejected. These live checks are required to verify the
shared endpoint after deployment.

The registration unit loads the same systemd credentials as `nextcloud-cron`.
These let `nextcloud-occ` read Nextcloud's database password and secret file
while running as `nextcloud`, without starting a privileged transient unit.
If an older deployment logs `systemd-run: Access denied`, rebuild emilia with
this configuration, then retry registration:

```sh
sudo systemctl restart nextcloud-context-agent-register
sudo journalctl -u nextcloud-context-agent-register -n 100 --no-pager
sudo nextcloud-occ app_api:app:list
```

The `app_api:*` commands are unavailable while AppAPI is disabled. Registration
enables the bundled `app_api` app before using those commands, so a failure on
its first OCC invocation also leaves those namespaces unavailable. A successful
backend `/heartbeat` alone does not confirm AppAPI registration.

## Enabling Garmin

```nix
homelab.services.hermes-agent.mcp.garmin.enable = true;
```

Garmin defaults to disabled, uses the upstream Hermes `mcpServers` option, and
requires native service mode. It opens no listening ports.

## Garmin Connect

The Garmin integration runs [Taxuspt/garmin_mcp](https://github.com/Taxuspt/garmin_mcp)
through `uvx` with a Nix-provided Python 3.12 interpreter. Its Git revision is
pinned by `mcp.garmin.revision`; the server and login helper share that revision.

On emilia, enabling Garmin also declares the `hermes/garmin-tokens` SOPS secret
from the private repository's `secrets/shared.yaml` and connects it to
`mcp.garmin.tokensFile`. Add that key before rebuilding. Its value is the entire
contents of a valid `garmin_tokens.json` as a multiline string, not base64:

```yaml
hermes:
  garmin-tokens: |
    <paste the complete garmin_tokens.json here>
```

Use SOPS to edit the encrypted file. No token values belong in this repository
or Nix expressions. The decrypted secret is owner-readable by Hermes, and secret
changes restart the gateway (and backend when enabled).

On other hosts, connect a sops-nix secret explicitly:

```nix
sops.secrets."hermes/garmin-tokens" = {
  owner = config.services.hermes-agent.user;
  group = config.services.hermes-agent.group;
  mode = "0400";
  restartUnits = [ "hermes-agent.service" ];
};
homelab.services.hermes-agent.mcp.garmin.tokensFile =
  config.sops.secrets."hermes/garmin-tokens".path;
```

At startup the secret is copied atomically to
`/var/lib/hermes/.garminconnect/garmin_tokens.json`, with directory mode `0700`
and file mode `0600`. Garmin gets a writable copy so it can refresh tokens;
the SOPS secret remains unchanged. Every service startup restores the declared
tokens. Update SOPS with renewed tokens before the declared tokens expire.

### First-time setup: generate the JSON before enabling Garmin

Run steps 1–4 on your trusted desktop or laptop as your regular user. This does
not require Garmin to be enabled on emilia, and does not require the
`hermes-garmin-auth` helper to exist yet. You need your Garmin Connect email,
password, and access to your MFA code if your account uses MFA.

1. Open a terminal and enter a shell with the required tools:

   ```sh
   nix shell nixpkgs#uv nixpkgs#python312 nixpkgs#git nixpkgs#jq nixpkgs#sops
   ```

   Keep using this terminal for the remaining local commands. The first login
   downloads the pinned Garmin package and its dependencies, so it needs
   outbound internet access.

1. Choose a private token directory outside this Git repository:

   ```sh
   umask 077
   export GARMINTOKENS="$HOME/.local/share/hermes-garmin-auth"
   export GARMINTOKENS_BASE64="$GARMINTOKENS/garmin_tokens.base64"
   mkdir -p "$GARMINTOKENS"
   chmod 700 "$GARMINTOKENS"
   ```

   `GARMINTOKENS` is a directory, not the path to the JSON file. The helper also
   writes a base64 copy; that copy is not used by this NixOS configuration.

1. Run the authentication command at the same revision as the Nix module:

   ```sh
   uvx --python python3.12 \
     --from 'git+https://github.com/Taxuspt/garmin_mcp@202913fde53c9d15890d661fc9748dc6d0d5af52' \
     garmin-mcp-auth --token-path "$GARMINTOKENS"
   ```

   Enter your Garmin Connect email at `Email:`, then your password at
   `Password:` (typing is hidden). If asked, enter the MFA code from your
   email/phone. Wait for `Authentication successful!` and the success message;
   the helper verifies that the saved tokens can log in. If Garmin reports
   rate limiting, wait a few minutes before trying again. Do not deploy tokens
   from a command that exits with an authentication error.

   The generated JSON is now at:
   `~/.local/share/hermes-garmin-auth/garmin_tokens.json`.
   If you change `mcp.garmin.revision`, use that revision in this command too.
   The flags and file-writing behavior are defined by the
   [pinned authentication helper](https://github.com/Taxuspt/garmin_mcp/blob/202913fde53c9d15890d661fc9748dc6d0d5af52/src/garmin_mcp/auth_cli.py).

1. Display the complete JSON so you can copy it into SOPS:

   ```sh
   jq . "$GARMINTOKENS/garmin_tokens.json"
   ```

   Copy everything from the opening `{` through the closing `}`. This output
   contains the credentials Hermes needs; keep it private. Use the JSON output,
   not `garmin_tokens.base64`, your Garmin password, or just one field from the
   JSON object.

1. In your checkout of the private `config-private` repository, open the
   encrypted secrets file:

   ```sh
   sops secrets/shared.yaml
   ```

   This requires your SOPS decryption key. In the editor, add `garmin-tokens`
   under the existing `hermes` mapping, alongside `env-file` and `cron-jobs`.
   Do not create a second `hermes` mapping. Use the block shown above:

   ```yaml
   hermes:
     garmin-tokens: |
       <paste the entire JSON object here>
   ```

   Replace the placeholder with the JSON; indent every JSON line at least four
   spaces so it belongs to the `|` string. Save and exit the editor; SOPS
   encrypts the value on save. Commit and push the encrypted `secrets/shared.yaml`
   in the private repository.

1. In this configuration repository, update the pinned private input so the
   rebuild can see the new secret:

   ```sh
   nix flake update my-secrets
   ```

   This requires your GitHub SSH agent. Commit `flake.lock` separately, as with
   other input updates. Uncomment `mcp.garmin.enable = true;` in
   `modules/machines/emilia/homelab/default.nix`, then rebuild emilia using your
   usual deployment command. The secret must be present in the pinned private
   input before the first rebuild with Garmin enabled.

1. On emilia, confirm the deployed tokens authenticate:

   ```sh
   sudo -Hu hermes hermes-garmin-auth --verify
   sudo journalctl -u hermes-agent -n 100 --no-pager
   ```

   Then ask Hermes for recent Garmin activities. No Garmin email/password is
   needed in `hermes/env-file`; the MCP server uses the deployed token JSON.

### Renewing tokens after deployment

On emilia, stop the gateway before replacing its tokens (also stop
`hermes-backend` if enabled), then authenticate as the Hermes service user:

```sh
sudo systemctl stop hermes-agent
sudo -Hu hermes hermes-garmin-auth --force-reauth
sudo -Hu hermes cat /var/lib/hermes/.garminconnect/garmin_tokens.json
```

Copy the complete JSON into the private SOPS key again, publish it, update
`my-secrets`, and rebuild emilia as in steps 5–6. Start the gateway again after
the updated secret has been deployed (`sudo systemctl start hermes-agent`; also
start `hermes-backend` if you stopped it). Do not restart with the old SOPS value:
every startup restores the declared secret over the writable token file.
Alternatively, generate renewed tokens on your desktop using steps 1–6, adding
`--force-reauth` to the login command in step 3.

The emilia helper always uses `/var/lib/hermes/.garminconnect` with the default
`stateDir`; changing `stateDir` changes the path. Run that helper as `hermes`,
not root or your regular user, so the service owns the resulting files. The
first-time desktop procedure intentionally uses a separate local directory.

## Applying and checking

Rebuild emilia after enabling Garmin and updating the private secret.
The module merges Nix MCP definitions into a private `configFile` after
activation and before each gateway/backend start. A restart alone cannot apply
this fix on older deployments: deploy the updated module first. Verify the
service profile explicitly, since `sudo` can reset `HERMES_HOME`:

```sh
sudo -u hermes env HERMES_HOME=/var/lib/hermes/.hermes hermes mcp list
```

Expect `nextcloud` and `garmin` on Emilia. This lists configured servers; it
does not test connectivity or authentication. Adjust the path if using a custom
`stateDir`. Remove previously copied definitions from the private config; Nix
now maintains their command paths, arguments, endpoint and credential references.

On first use, uv downloads the pinned Garmin source and its Python dependencies
as the Hermes user. The host needs outbound network access and writable caches
under Hermes's state directory.
These are runtime installs; transitive dependencies are not locked by `flake.lock`.

Restart `hermes-agent` after credential changes or Garmin authentication, then
check `journalctl -u hermes-agent` for MCP discovery errors. In Hermes, request
recent Garmin activities to verify authenticated access.
The initial connection timeout is 180 seconds to allow first-run installation.

Additional servers and tool filters can be configured through
`services.hermes-agent.mcpServers` using the
[upstream MCP configuration](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/mcp.md).

Run the private-config merge regression tests with the pinned package's
`hermesVenv/bin/python3`:

```sh
python3 modules/homelab/services/hermes-agent/test-mcp-config.py
```
