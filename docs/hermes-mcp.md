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
adds the remote `nextcloud` server to the Nix-managed Hermes service profile's
`mcp_servers`, using the configured Nextcloud hostname and a literal
`${NEXTCLOUD_APP_PASSWORD}` reference. The password is resolved at runtime.
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

To obtain the initial token JSON, authenticate once with the pinned project's
`garmin-mcp-auth` command on a trusted machine. Alternatively, after enabling
Garmin and rebuilding, use the provided helper on emilia:

```sh
sudo -Hu hermes hermes-garmin-auth
```

The helper prompts for your Garmin credentials and MFA when required. Tokens
are saved in `/var/lib/hermes/.garminconnect`, shared with the MCP subprocess.
Changing `stateDir` changes this path for both commands. Do not authenticate as
root or your regular user: the service needs its own tokens. Re-run the helper
when tokens expire; `hermes-garmin-auth --verify` checks saved tokens. Save the
resulting `garmin_tokens.json` to SOPS before restarting, otherwise startup will
restore the older declared tokens. A first deployment needs tokens generated
elsewhere before enabling Garmin on emilia.
Garmin email/password are only needed for obtaining tokens, not deployment.

## Applying and checking

Rebuild emilia after enabling Garmin and updating the private secret.
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
