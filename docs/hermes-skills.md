# Private declarative Hermes skills

Set `homelab.services.hermes-agent.skillsFile` to a sops-nix secret's runtime
path. Skill contents are read only at service startup and stay out of the Nix
store. Native service mode is required.

After adding the encrypted secret and updating the pinned `my-secrets` input,
add this to `modules/machines/emilia/homelab/default.nix`:

```nix
sops.secrets."hermes/skills" = {
  sopsFile = "${secretsPath}/secrets/shared.yaml";
  owner = config.services.hermes-agent.user;
  group = config.services.hermes-agent.group;
  mode = "0400";
  restartUnits = [ "hermes-agent.service" ]
    ++ lib.optionals (config.homelab.services.hermes-agent.backend.mode != "none") [ "hermes-backend.service" ];
};

homelab.services.hermes-agent.skillsFile =
  config.sops.secrets."hermes/skills".path;
```

In the private repository's `secrets/shared.yaml`, add `skills` alongside the
other `hermes` keys as a multiline string containing a JSON list. Each entry
has a `name`, `category`, and `files` field. For example, this declares one
skill in `devops` and one in `productivity`:

```yaml
hermes:
    skills: |
      [
        {
          "name": "deploy-helper",
          "category": "devops",
          "files": {
            "SKILL.md": "---\nname: deploy-helper\ndescription: Help deploy my services.\n---\n\nFollow the deployment runbook.\n"
          }
        },
        {
          "name": "daily-review",
          "category": "productivity",
          "files": {
            "SKILL.md": "---\nname: daily-review\ndescription: Prepare a daily review using my private workflow.\n---\n\nRead references/workflow.md and prepare the review.\n",
            "references/workflow.md": "Review my calendar and outstanding tasks. Ask before changing anything.\n"
          }
        }
      ]
```

Encrypt before committing. Each `name` and `category` uses lowercase letters,
digits, and single separating hyphens. `name` is the skill directory name. The
category selects the directory under `skills/`. Each skill's `files` map
contains relative file paths and UTF-8 text, including a required nonempty
`SKILL.md`. Use Hermes's
normal YAML frontmatter (`name`, `description`) and Markdown instructions.
Companion files such as `references/`, `templates/`, and `scripts/` are supported;
files under `scripts/` are executable. Binary files and nested skills are not
supported. Absolute paths, traversal, duplicate JSON keys, and conflicting file
paths are rejected before publishing changes.

Before gateway or backend startup, the module publishes a complete generation
in `$HERMES_HOME/.nixos-skills/` and atomically switches the
`$HERMES_HOME/skills/<category>` symlink for each declared category. The pinned
Hermes skill discovery follows these symlinks and discovers each `SKILL.md`.
Existing category directories are adopted: unrelated entries are copied into
the new generation, and declared skill directories are replaced by their
declarations. Unrelated symlinks in an existing category cause startup to fail
rather than follow them. When a category is removed, managed skills are removed
and unrelated entries are restored as a normal directory. Other installed,
bundled, and interactively created skills are preserved. Use unique frontmatter
names to avoid collisions with those skills.

Changes and removals are applied on startup; edits to managed runtime files
are replaced. Declare `[]` and restart to remove all managed skills before
unsetting `skillsFile`. Unsetting the option alone leaves the last generation
in place. SOPS secret changes restart both configured services via
`restartUnits`; a lock serializes their reconciliation.

Runtime contents remain plaintext, owned by the Hermes service user. Generation
directories are private, ordinary files use mode `0600`, and scripts use `0700`.
Journal errors omit secret contents. The module is opt-in so existing hosts do
not require a new SOPS key until the encrypted secret is available.

Run the reconciler tests with Python 3:

```sh
python3 modules/homelab/services/hermes-agent/test-skills.py
```
