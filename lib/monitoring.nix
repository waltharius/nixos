# lib/monitoring.nix
#
# NixOS module generated from the inventory, imported by every host
# (lib/default.nix). What a host gets depends on its role:
#
#   class server or virtual   - node_exporter (modules/servers/monitoring/
#                               node-exporter.nix) with the textfile
#                               collector; its port is open only to the
#                               monitoring server
#   class server (bare metal) - additionally smartctl_exporter and a monthly
#                               btrfs scrub whose result is exported through
#                               the textfile collector (smartctl.nix,
#                               btrfs-scrub.nix); hardware alerts apply
#   monitoring server         - Prometheus, Alertmanager, Postfix, blackbox
#   (hosts/fleet.nix)           exporter and Grafana (modules/servers/
#                               monitoring/default.nix)
#   workstations              - nothing (laptops are not monitored)
#
# Scrape targets are derived from the inventory, so adding a machine with
# `nix run .#new-host` or a device file in hosts/devices/ is enough to get
# it monitored after the next deploy of the monitoring server:
#   - machines of class server/virtual: node_exporter (and smartctl for
#     class server), plus an ICMP probe;
#   - devices with `monitoring.ping = true`: an ICMP probe;
#   - devices with `monitoring.pve = true`: the Proxmox API, read by the pve
#     exporter on the monitoring server (modules/servers/monitoring/pve.nix);
#   - devices with `monitoring.cadvisor = true`: cAdvisor (container
#     metrics) on port 8080, installed by `nix run .#fleet` (task
#     "monitoring apply", ansible/playbooks/cadvisor.yml);
#   - hosts/websites.nix: an HTTP probe per page.
# The generated lists are exposed as `fleet.monitoring.targets` and read by
# modules/servers/monitoring/prometheus.nix. See docs/MONITORING.md.
{
  lib,
  inventory,
}: {
  config,
  host,
  ...
}: let
  inherit (inventory) machines devices websites;
  cfg = inventory.monitoring;

  serverName = cfg.server;
  serverAddress = machines.${serverName}.lan.ip;

  isMonitored = m: builtins.elem m.class ["server" "virtual"];
  isBaremetal = m: m.class == "server";

  role = {
    monitored = isMonitored host;
    baremetal = isBaremetal host;
    server = host.name == serverName;
  };

  ports = {
    node = 9100;
    smartctl = 9633;
  };

  exporterPorts = lib.unique config.fleet.monitoring.exporterPorts;

  monitoredMachines = lib.filterAttrs (_: isMonitored) machines;
  baremetalMachines = lib.filterAttrs (_: isBaremetal) machines;
  pingedDevices = lib.filterAttrs (_: d: d.monitoring.ping or false) devices;
  pveDevices = lib.filterAttrs (_: d: d.monitoring.pve or false) devices;
  cadvisorDevices = lib.filterAttrs (_: d: d.monitoring.cadvisor or false) devices;
  # Must match cadvisor_port in ansible/playbooks/cadvisor.yml.
  cadvisorPort = 8080;

  boolLabel = b:
    if b
    then "true"
    else "false";

  # One scrape target: address plus the labels attached to every series.
  # `instance` is set to the host name so dashboards and alerts show names
  # instead of addresses.
  machineTarget = port: name: m: {
    address = "${m.lan.ip}:${toString port}";
    labels = {
      instance = name;
      host = name;
      class = m.class;
      baremetal = boolLabel (isBaremetal m);
    };
  };

  pingTarget = kind: name: x: {
    address = x.lan.ip;
    labels = {
      instance = name;
      host = name;
      inherit kind;
    };
  };

  targets = {
    node = lib.mapAttrsToList (machineTarget ports.node) monitoredMachines;
    smartctl = lib.mapAttrsToList (machineTarget ports.smartctl) baremetalMachines;
    # The monitoring server does not ping itself: if it is down, nothing
    # evaluates the alert anyway (the Watchdog covers that case).
    ping =
      lib.mapAttrsToList (pingTarget "machine") (lib.filterAttrs (n: _: n != serverName) monitoredMachines)
      ++ lib.mapAttrsToList (pingTarget "device") pingedDevices;
    # Proxmox hosts. The address is the API host the exporter connects to
    # (https://<address>:8006); it must be in the pveproxy certificate.
    pve =
      lib.mapAttrsToList (name: d: {
        address = d.lan.ip;
        labels = {
          instance = name;
          host = name;
        };
      })
      pveDevices;
    # Docker hosts without NixOS. The monitoring server adds its own
    # cAdvisor (Podman) as a local target (modules/servers/monitoring/cadvisor.nix).
    cadvisor =
      lib.mapAttrsToList (name: d: {
        address = "${d.lan.ip}:${toString cadvisorPort}";
        labels = {
          instance = name;
          host = name;
          runtime = "docker";
        };
      })
      cadvisorDevices;
    websites =
      lib.mapAttrsToList (name: w: {
        address = w.url;
        labels = {
          instance = name;
          site = name;
        };
      })
      websites;
  };
in {
  imports =
    lib.optional role.monitored ../modules/servers/monitoring/node-exporter.nix
    ++ lib.optionals role.baremetal [
      ../modules/servers/monitoring/smartctl.nix
      ../modules/servers/monitoring/btrfs-scrub.nix
    ]
    ++ lib.optional role.server ../modules/servers/monitoring;

  options.fleet.monitoring = {
    serverAddress = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "LAN address of the monitoring server (hosts/fleet.nix); the only source allowed to reach exporter ports.";
    };
    ports = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      readOnly = true;
      description = "Ports of the exporters every monitored host runs.";
    };
    textfileDir = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        Directory read by node_exporter's textfile collector. Jobs write
        <name>.prom files in the Prometheus text format here (write a
        temporary file in the same directory, then rename it).
      '';
    };
    mail = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Alert e-mail settings from hosts/fleet.nix (`to`, `from`).";
    };
    targets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.attrs);
      readOnly = true;
      description = "Scrape targets generated from the inventory, read by the Prometheus configuration.";
    };
    exporterPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      internal = true;
      description = ''
        TCP ports of exporters running on this host. Each exporter module
        adds its port; the firewall opens them to the monitoring server's
        address only.
      '';
    };
  };

  config = lib.mkMerge [
    {
      fleet.monitoring = {
        inherit serverAddress ports targets;
        inherit (cfg) mail;
        textfileDir = "/var/lib/node-exporter-textfile";
      };
    }

    # Exporters listen on all addresses (no start-up race with the network
    # configuration); the firewall lets only the monitoring server in. The
    # rule depends on the firewall backend: nftables on altair, iptables in
    # the Proxmox LXC containers.
    (lib.mkIf (exporterPorts != [] && config.networking.nftables.enable) {
      networking.firewall.extraInputRules = ''
        ip saddr ${serverAddress} tcp dport { ${lib.concatMapStringsSep ", " toString exporterPorts} } accept comment "monitoring server -> exporters"
      '';
    })
    (lib.mkIf (exporterPorts != [] && !config.networking.nftables.enable) {
      networking.firewall.extraCommands =
        lib.concatMapStrings (port: ''
          iptables -A nixos-fw -p tcp -s ${serverAddress} --dport ${toString port} -j nixos-fw-accept
        '')
        exporterPorts;
    })
  ];
}
