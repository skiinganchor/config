# Emilia Fail2ban ignore list

Emilia reads its Fail2ban ignore list from the `fail2ban/ignoreip` SOPS secret
in the private repository's `secrets/emilia.yaml`. The secret is a Fail2ban INI
snippet included after the generated jail configuration, so keep the `[DEFAULT]`
section header and the complete `ignoreip` list in its value.

For example, add the following YAML key to `secrets/emilia.yaml` and encrypt it
with SOPS before committing:

```yaml
fail2ban:
    ignoreip: |
        [DEFAULT]
        ignoreip = 127.0.0.1/8 ::1 192.168.1.4
```

Put one or more IP addresses, CIDR ranges, or hostnames after `ignoreip =`,
separated by spaces. Include loopback addresses if they should remain exempt:
the secret value replaces Fail2ban's generated default list. The secret is
declared by Emilia's homelab module and changes restart `fail2ban.service`.

The fail2ban service module is shared across machines, so machine-specific
addresses belong in the host's SOPS file rather than in the shared Nix module.
