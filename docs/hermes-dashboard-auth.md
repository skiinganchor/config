# Private Hermes dashboard authentication

Hermes refuses to start its dashboard on a non-loopback address unless an
authentication provider is configured. Do not disable the auth gate. This
example uses Hermes's built-in basic authentication. Set `password` in the
encrypted SOPS config; Hermes hashes it in memory, so no hash-generation
command is needed.

## Store a complete Hermes config in SOPS

In the private repository's `secrets/shared.yaml`, add `config-file`
under the existing `hermes` key. This secret contains the **complete** Hermes
`config.yaml` contents. Preserve any other Hermes settings you currently
configure through Nix when moving them into this file.

```yaml
hermes:
    config-file: |
      dashboard:
        basic_auth:
          username: "dashboard-user"
          password: "REPLACE_WITH_A_LONG_RANDOM_PASSWORD"
      # Add your other Hermes config.yaml settings here.
```

Encrypt the value with SOPS before committing. Do not add the password to a
Nix `settings` attribute: Nix evaluates settings into the store, while the
secret must remain a runtime file. Hermes's runtime `config.yaml` contains the
decrypted password, so keep that file private to the Hermes service user. To
store only a hash in the runtime config instead, Hermes also supports
`password_hash`; that requires generating the hash with Hermes's Python helper.

In Emilia's `modules/machines/emilia/homelab/default.nix`, declare the
decrypted file and point the upstream Hermes module at it:

```nix
sops.secrets."hermes/config-file" = {
  sopsFile = "${secretsPath}/secrets/shared.yaml";
  owner = config.services.hermes-agent.user;
  group = config.services.hermes-agent.group;
  mode = "0400";
  restartUnits = [ "hermes-agent.service" "hermes-backend.service" ];
};

homelab.services.hermes-agent.configFile =
  config.sops.secrets."hermes/config-file".path;
```

The `configFile` option replaces Nix-generated Hermes settings entirely; do
not use it unless the complete Hermes config is represented in the secret.
In particular, enabled Nix `mcpServers` are not automatically included: copy
their definitions into the secret's `mcp_servers` mapping. On Emilia, inspect
the Nix-generated definitions with:

```sh
nix eval --json .#nixosConfigurations.emilia.config.services.hermes-agent.mcpServers
```

JSON is valid YAML, so the resulting object can be used as the value of
`mcp_servers` in the secret. Re-copy the definitions when their Nix settings or
store paths change. Do not paste credentials into the Nix configuration.
The decrypted file is copied into Hermes's runtime state on activation, and
the password does not enter the Nix store.

Set `homelab.services.hermes-agent.backend.host` to Emilia's LAN IP address,
and browse to `http://<that-same-ip>:9119`. Hermes validates the request
`Host` header against its bind address. Keep TCP port `9119` restricted to
trusted LAN/WireGuard sources in nftables.

After updating the private secret and deploying the flake, check
`systemctl status hermes-backend` and `ss -ltnp | grep 9119`. The dashboard
should prompt for the configured username and password.
