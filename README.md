# config

To update flake you need to use ssh-agent. Based on https://git.notthebe.ee/notthebee/nix-config

## GitHub Actions secrets

### `GH_TOKEN_FOR_UPDATES`

The [`update-flake-lock`](.github/workflows/update-flake-lock.yml) workflow uses this token to push the updated lock-file branch and open a pull request. The final merge step also uses it with `gh pr merge --admin`, so the token owner must be a repository admin.

Create the token in **User Settings → Developer settings → Personal access tokens → Fine-grained tokens** and store it in **Repository Settings tabs → Secrets and variables → Actions → Environment secrets** for the `production` environment.

#### Classic PAT (simplest)

1. Generate a new classic token.
2. Select the `repo` scope (full control of private repositories).

#### Fine-grained PAT

1. Generate a new fine-grained token.
2. Add `skiinganchor/config` to the repository access list.
3. Grant **Contents** and **Pull requests** read and write permissions.

#### `GH_PRIVATE_KEY`

An SSH private key used by [`webfactory/ssh-agent`](https://github.com/webfactory/ssh-agent) so Nix can fetch private flake inputs such as `skiinganchor/config-private` during `nix flake update`.
