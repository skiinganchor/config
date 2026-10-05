{ pkgs }:
let
  datasource = { type = "prometheus"; uid = "prometheus"; };
  # UID and variable names belong to the pinned Node Exporter Full revision
  # in dashboards.nix. Pass both nodename and instance: its node variable
  # depends on nodename, which can differ from the scrape target's DNS name.
  drilldown = "/d/rYdddlPWk/node-exporter-full?var-ds_prometheus=prometheus&var-job=node&var-nodename=\${__data.fields.nodename}&var-node=\${__data.fields.Machine}&\${__url_time_range}";
  fieldOverride = name: properties: {
    matcher = { id = "byName"; options = name; };
    inherit properties;
  };
  percentOverride = name: fieldOverride name [
    { id = "unit"; value = "percent"; }
    { id = "min"; value = 0; }
    { id = "max"; value = 100; }
    { id = "custom.cellOptions"; value = { type = "gauge"; mode = "basic"; }; }
    {
      id = "thresholds";
      value = {
        mode = "absolute";
        steps = [
          { color = "green"; value = null; }
          { color = "yellow"; value = 75; }
          { color = "red"; value = 90; }
        ];
      };
    }
  ];
  mkMatrix = { id, title, selector, y }:
    let
      # Join resource metrics to the target inventory rather than to uname:
      # up remains present when an exporter is down. Gate usage by up so a
      # failed scrape shows Unknown instead of potentially stale good values.
      inventory = "up{job=\"node\",${selector}}";
      live = "(max by (instance) (${inventory}) == 1)";
      scope = expr: "(${expr}) and on (instance) ${live}";
      target = refId: expr: {
        inherit refId expr datasource;
        editorMode = "code";
        format = "table";
        instant = true;
        range = false;
      };
    in
    {
      inherit id title datasource;
      type = "table";
      description = "One row per exporter. Click a machine for Node Exporter Full. CPU and network use the selected range's rate interval; memory and filesystem usage are current. Filesystem shows the fullest writable real filesystem. Unknown means the exporter is down or a metric is unavailable.";
      gridPos = { x = 0; inherit y; w = 24; h = 9; };
      targets = [
        (target "A" "max by (instance) (${inventory})")
        # Keep the actual uname for drilldown even during short outages.
        (target "B" ''
          max by (instance, nodename) (
            (${inventory} * on (instance) group_left (nodename) max by (instance, nodename) (last_over_time(node_uname_info{job="node"}[24h])))
            or on (instance)
            label_replace(${inventory}, "nodename", "$1", "instance", "([^:]+):.*")
          )
        '')
        (target "C" (scope ''100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{job="node",mode="idle"}[$__rate_interval])))''))
        (target "D" (scope ''100 * (1 - max by (instance) (node_memory_MemAvailable_bytes{job="node"}) / max by (instance) (node_memory_MemTotal_bytes{job="node"}))''))
        (target "E" (scope ''max by (instance) (100 * (1 - node_filesystem_avail_bytes{job="node",fstype!~"tmpfs|devtmpfs|squashfs|overlay|nsfs|ramfs",mountpoint!~"/run($|/.*)|/var/lib/(docker|containers)($|/.*)"} / node_filesystem_size_bytes{job="node"}) and node_filesystem_readonly{job="node"} == 0 and node_filesystem_size_bytes{job="node"} > 0)''))
        (target "F" (scope ''sum by (instance) (rate(node_network_receive_bytes_total{job="node",device!~"lo|veth.*|docker.*|br.*|vmbr.*|virbr.*|tap.*|vnet.*|fw.*"}[$__rate_interval]))''))
        (target "G" (scope ''sum by (instance) (rate(node_network_transmit_bytes_total{job="node",device!~"lo|veth.*|docker.*|br.*|vmbr.*|virbr.*|tap.*|vnet.*|fw.*"}[$__rate_interval]))''))
      ];
      transformations = [
        { id = "joinByField"; options = { byField = "instance"; mode = "outerTabular"; }; }
        {
          id = "filterFieldsByName";
          options.include.names = [ "instance" "nodename" "Value #A" "Value #C" "Value #D" "Value #E" "Value #F" "Value #G" ];
        }
        {
          id = "organize";
          options = {
            indexByName = {
              instance = 0;
              "Value #A" = 1;
              "Value #C" = 2;
              "Value #D" = 3;
              "Value #E" = 4;
              "Value #F" = 5;
              "Value #G" = 6;
              nodename = 7;
            };
            renameByName = {
              instance = "Machine";
              "Value #A" = "Status";
              "Value #C" = "CPU";
              "Value #D" = "Memory";
              "Value #E" = "Fullest filesystem";
              "Value #F" = "Network RX";
              "Value #G" = "Network TX";
            };
          };
        }
      ];
      fieldConfig = {
        defaults = {
          color.mode = "thresholds";
          custom = { align = "auto"; cellOptions.type = "auto"; filterable = false; };
          decimals = 1;
          noValue = "Unknown";
        };
        overrides = [
          (fieldOverride "Machine" [
            { id = "custom.width"; value = 240; }
            { id = "links"; value = [{ title = "Node Exporter Full"; url = drilldown; }]; }
            {
              id = "mappings";
              value = [{
                type = "value";
                options = {
                  "desktop:9100".text = "nixos (desktop)";
                  "localhost:9100".text = "alertson";
                  "saga:9100".text = "Intel NUC (saga)";
                  "nas:9100".text = "NAS";
                  "pbs:9100".text = "Proxmox Backup Server (pbs)";
                };
              }];
            }
          ])
          # Hide via an override, not a transformation: data links still
          # need this field in the same row.
          (fieldOverride "nodename" [{ id = "custom.hidden"; value = true; }])
          (fieldOverride "Status" [
            { id = "custom.width"; value = 110; }
            { id = "custom.cellOptions"; value = { type = "color-background"; mode = "basic"; }; }
            {
              id = "mappings";
              value = [{
                type = "value";
                options = {
                  "0" = { text = "DOWN"; color = "red"; };
                  "1" = { text = "UP"; color = "green"; };
                };
              }];
            }
          ])
          (percentOverride "CPU")
          (percentOverride "Memory")
          (percentOverride "Fullest filesystem")
          (fieldOverride "Network RX" [{ id = "unit"; value = "Bps"; }])
          (fieldOverride "Network TX" [{ id = "unit"; value = "Bps"; }])
        ];
      };
      options = {
        showHeader = true;
        cellHeight = "md";
        footer.show = false;
        sortBy = [{ displayName = "Machine"; desc = false; }];
      };
    };
in
pkgs.writeText "machines-overview.json" (builtins.toJSON {
  uid = "homelab-machines";
  title = "Homelab Machines Overview";
  description = "Physical hosts and VMs grouped by Prometheus machine_type and hypervisor target labels.";
  tags = [ "homelab" "node-exporter" ];
  schemaVersion = 39;
  version = 1;
  editable = false;
  timezone = "browser";
  refresh = "30s";
  time = { from = "now-1h"; to = "now"; };
  templating.list = [ ];
  panels = [
    (mkMatrix { id = 1; title = "Physical machines"; selector = ''machine_type="physical"''; y = 0; })
    (mkMatrix { id = 2; title = "Intel NUC / Proxmox VMs (saga)"; selector = ''machine_type="vm",hypervisor="saga"''; y = 9; })
    (mkMatrix { id = 3; title = "NAS VMs"; selector = ''machine_type="vm",hypervisor="nas"''; y = 18; })
  ];
})
