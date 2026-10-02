# modules/servers/monitoring/node-exporter.nix
#
# Prometheus node exporter - OS and hardware metrics. Imported by
# lib/monitoring.nix on every machine of class server or virtual.
#
# Listens on all addresses; the firewall opens the port to the monitoring
# server only (lib/monitoring.nix). Hardware collectors (hwmon,
# thermal_zone) find nothing in a container, which is harmless; hardware
# alerts only look at bare-metal hosts (label baremetal="true").
#
# Textfile collector: every *.prom file in fleet.monitoring.textfileDir is
# exported as if node_exporter had measured it itself. Jobs that measure
# something node_exporter cannot (btrfs scrub results, later backups and
# vulnerability scans) write their results there.
{config, ...}: let
  mon = config.fleet.monitoring;
in {
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = mon.ports.node;
    # Collectors that are not enabled by default; the defaults stay on.
    enabledCollectors = [
      "systemd" # unit states - feeds SystemdUnitFailed
      "processes"
    ];
    extraFlags = [
      "--collector.textfile.directory=${mon.textfileDir}"
      # Virtual and kernel filesystems are noise; /nix/store is a read-only
      # bind mount of the filesystem /nix is on.
      "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run|tmp|nix/store)($|/)"
      "--collector.filesystem.fs-types-exclude=^(tmpfs|devtmpfs|devpts|sysfs|proc|cgroup|cgroup2|overlay|squashfs|fuse\\..*)$"
      # Virtual network interfaces (containers, bridges, VPN).
      "--collector.netdev.device-exclude=^(lo|veth.*|incus.*|docker.*|podman.*|cni-.*|tailscale.*)$"
    ];
  };

  fleet.monitoring.exporterPorts = [mon.ports.node];

  # Readable by node_exporter, writable by root-owned jobs only.
  systemd.tmpfiles.rules = ["d ${mon.textfileDir} 0755 root root -"];
}
