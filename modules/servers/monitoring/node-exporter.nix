# modules/servers/monitoring/node-exporter.nix
#
# Prometheus node exporter — host hardware/OS metrics.
# Binds loopback only. Prometheus scrapes 127.0.0.1:9100.
# corsair-psu kmod is already loaded in hardware-configuration.nix —
# hwmon collector picks it up automatically via /sys/class/hwmon.
{...}: {
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [
      "cpu"
      "diskstats"
      "filesystem"
      "hwmon" # picks up k10temp (AMD CPU), corsair-psu, ASUS EC sensors
      "loadavg"
      "meminfo"
      "netdev"
      "netstat"
      "processes"
      "systemd" # exposes unit states — feeds SystemdUnitFailed alert
      "thermal_zone"
      "time"
      "uname"
    ];
    extraFlags = [
      # Exclude virtual/kernel filesystems from disk metrics — reduces noise
      "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run|tmp)($|/)"
      "--collector.filesystem.fs-types-exclude=^(tmpfs|devtmpfs|devpts|sysfs|proc|cgroup|overlay)$"
      # Ignore virtual/loopback network interfaces
      "--collector.netdev.device-exclude=^(lo|veth|incus|incusbr|docker).*$"
    ];
  };
}
