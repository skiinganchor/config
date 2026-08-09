{ pkgs }:
let
  # Pin revision and content hash so the fetched dashboard JSON is
  # reproducible; any upstream change surfaces as a build error instead
  # of silent drift.
  mkDashboard =
    { id, rev, sha256 }:
    pkgs.fetchurl {
      url = "https://grafana.com/api/dashboards/${toString id}/revisions/${toString rev}/download";
      inherit sha256;
    };

  nodeExporterFull = mkDashboard {
    id = 1860;
    rev = 45;
    sha256 = "11hrll7fm626ikbva5md4gm0rca537vp4xsxa9sxl1pk15s6nk0q";
  };

  systemdExporter = mkDashboard {
    id = 23844;
    rev = 3;
    sha256 = "0zphdrf18hsnvxj00nfmq3ajyb5jl6mgy20ljcpjzqjjqsz5c2pz";
  };

  smartctlExporter = mkDashboard {
    id = 22381;
    rev = 1;
    sha256 = "sha256-E1f+UvVNxg9DsvkLIsUwIqfFm5K+Wd4kKIg+8h1uxpg=";
  };

  # Grafana's provisioning layer does not substitute env vars into dashboard
  # JSON, so the correct datasource has to be baked in here. The pipeline
  # drops `__inputs` (Grafana.com import variables this config does not
  # provide) and rewrites the datasource template variable to the local
  # UID `prometheus` (defined in ./default.nix), then hides it (`hide: 2`) so
  # users cannot pick another datasource from the UI.
  fixDatasourceVars = ''
    del(.__inputs)
    | .templating.list |= map(
        if .type == "datasource" then
          .current = { text: "Prometheus", value: "prometheus", selected: false }
          | .hide = 2
        else
          .
        end
      )
  '';
in
# $out is consumed by Grafana's declarative file provider in this directory;
  # every JSON file written below becomes a provisioned dashboard.
pkgs.runCommand "grafana-dashboards"
{
  nativeBuildInputs = [ pkgs.jq ];
}
  ''
    mkdir -p $out
    jq '${fixDatasourceVars}' "${nodeExporterFull}" > "$out/node-exporter-full.json"
    # The Systemd exporter JSON still uses the legacy ''${DS_PROMETHEUS}
    # placeholder in its queries; sed rewrites it to ''${datasource} so it
    # binds to the template variable defined in fixDatasourceVars above.
    jq '${fixDatasourceVars}' "${systemdExporter}" | sed 's/''${DS_PROMETHEUS}/''${datasource}/g' > "$out/systemd-exporter.json"
    jq '${fixDatasourceVars}' "${smartctlExporter}" | sed 's/''${DS_VICTORIAMETRICS}/''${datasource}/g' > "$out/smartctl-exporter.json"
  ''
