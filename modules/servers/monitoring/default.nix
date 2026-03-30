# modules/servers/monitoring/default.nix
# Import all monitoring modules. Add to hosts/servers/altair/default.nix.
{...}: {
  imports = [
    ./prometheus.nix
    ./grafana.nix
    ./node-exporter.nix
    ./nvidia-exporter.nix
  ];
}
