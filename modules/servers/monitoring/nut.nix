# modules/servers/monitoring/nut.nix
#
# nut_exporter on the monitoring server: reads UPSes from the NUT servers
# (upsd, port 3493) of devices with `monitoring.ups = "<name>"`, e.g. the
# APC Back-UPS on pfSense. Nothing is installed on the device; upsd must
# listen on the LAN. Reading variables needs no NUT login (NUT's default),
# so no credentials are stored. Prometheus passes the device address as
# ?server= and the UPS name as ?ups= (job `nut` in prometheus.nix); the
# exporter listens on loopback.
{
  config,
  lib,
  ...
}: let
  targets = config.fleet.monitoring.targets.nut;
in {
  config = lib.mkIf (targets != []) {
    services.prometheus.exporters.nut = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9199;
      # The exporter's defaults plus runtime and the voltage limits used
      # by its Grafana dashboard. Variables a UPS does not report are
      # simply missing.
      nutVariables = [
        "battery.charge"
        "battery.charge.low"
        "battery.runtime"
        "battery.voltage"
        "battery.voltage.high"
        "battery.voltage.low"
        "battery.voltage.nominal"
        "input.voltage"
        "input.voltage.nominal"
        "ups.load"
        "ups.realpower.nominal"
        "ups.status"
      ];
    };
  };
}
