# Private declarative Hermes cron jobs

Set `homelab.services.hermes-agent.cronJobsFile` to a sops-nix secret's
runtime path. The decrypted file is a JSON list; no private fields are evaluated
by Nix or copied to the Nix store. Native service mode is required.

For example, add this configuration to the desktop's NixOS modules:

```nix
sops.secrets."hermes/cron-jobs" = {
  sopsFile = "${my-secrets}/secrets/shared.yaml";
  owner = config.services.hermes-agent.user;
  group = config.services.hermes-agent.group;
  mode = "0400";
  restartUnits = [ "hermes-agent.service" ];
};

homelab.services.hermes-agent.cronJobsFile =
  config.sops.secrets."hermes/cron-jobs".path;
```

In the private repository, use SOPS to add the `hermes/cron-jobs` YAML key
(nested under `hermes`, alongside `env-file`) as a multiline string:

```yaml
hermes:
    cron-jobs: |
      [
        {
          "id": "morning-summary",
          "name": "Morning summary",
          "schedule": "0 9 * * *",
          "deliver": "matrix:!room-id:example.org",
          "prompt": "Prepare my morning summary.",
          "skills": ["morning-briefing", "weather"]
        }
      ]
```

Encrypt this value before committing it. Keep `id` stable when changing the
name, schedule, delivery room, prompt, or skills. The `id`, `name`, `schedule`,
`deliver`, and `prompt` fields are required nonempty strings; `skills` is an
optional list of nonempty, unique skill names (default `[]`). Skills must already
be installed in Hermes and are loaded in the listed order. IDs must be unique.
Schedules support Hermes recurring cron expressions
and intervals such as `every 2h`; one-shot schedules are rejected. Times use
Hermes's configured timezone (`settings.timezone`, for example
`"Europe/Amsterdam"`). Delivery uses an explicit Matrix room ID. The gateway
must already have Matrix credentials configured through `environmentFile` and
access to the destination room.

Before each gateway start, the module validates the whole list, creates new jobs,
updates changed fields, and removes previously managed jobs absent from the list.
Existing IDs, run history, and unchanged next-run times are retained. Jobs created
interactively are left alone, and an interactive pause is preserved. Changes to
declared fields are reapplied on the next restart. Use `[]` and rebuild/restart
to remove all managed jobs before unsetting `cronJobsFile`; unsetting the option
alone stops reconciliation.

SOPS changes restart the gateway via `restartUnits`. Managed job definitions and
run output remain plaintext in Hermes's private runtime state, as required by
its scheduler. Reconciliation runs as the Hermes user with a restrictive umask;
errors in the journal omit private field values. It uses the pinned package's
Python cron API, so verify reconciliation when upgrading the Hermes input.
