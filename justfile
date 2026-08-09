# vim: set ft=make :

update:
  nix flake update

check:
  nix flake check

test-rules:
  promtool check rules modules/homelab/services/monitoring/prometheus/rules/homelab.yml
  promtool test rules modules/homelab/services/monitoring/prometheus/tests/rules_test.yml

# dry-run $host:
# 	nixos-rebuild dry-activate --flake .#{{host}} --target-host {{host}} --build-host {{host}} --fast --use-remote-sudo

# deploy $host:
# 	nixos-rebuild switch --flake .#{{host}} --target-host {{host}} --build-host {{host}} --fast --use-remote-sudo && rsync -ax --delete --rsync-path="sudo rsync" ./ {{host}}:/etc/nixos/
