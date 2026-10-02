# modules/servers/monitoring/smartctl.nix
#
# S.M.A.R.T. data of the physical disks (health status, temperature, NVMe
# wear and media errors) through smartctl_exporter. Imported by
# lib/monitoring.nix on machines of class server (bare metal). Alerts:
# SmartHealthFailed, DiskTemperatureHigh, NvmeCriticalWarning,
# NvmeWearHigh (modules/servers/monitoring/alert-rules.nix).
#
# Devices are discovered automatically. The port is open to the monitoring
# server only (lib/monitoring.nix).
{config, ...}: let
  mon = config.fleet.monitoring;
in {
  services.prometheus.exporters.smartctl = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = mon.ports.smartctl;
  };

  fleet.monitoring.exporterPorts = [mon.ports.smartctl];
}
