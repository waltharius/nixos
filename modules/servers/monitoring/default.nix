# modules/servers/monitoring/default.nix
#
# Monitoring server: imported by lib/monitoring.nix on the machine named in
# `monitoring.server` (hosts/fleet.nix). Exporters that every monitored
# host runs (node, smartctl, btrfs scrub) are imported by lib/monitoring.nix
# separately; GPU metrics are hardware-specific and imported by the host
# (hosts/physical/altair/configuration.nix -> nvidia-exporter.nix).
# Overview: docs/MONITORING.md.
{...}: {
  imports = [
    ./prometheus.nix
    ./alertmanager.nix
    ./mail.nix
    ./blackbox.nix
    ./grafana.nix
  ];
}
