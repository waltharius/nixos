# modules/servers/monitoring/prometheus.nix
#
# Prometheus on the monitoring server. Retention 90 days. Grafana queries it
# over loopback. The web UI is open on the LAN interface (port 9090, no
# authentication; the LAN is trusted) so the "Source" links in alert
# e-mails work: they are built from `webExternalUrl`, by default
# http://<host name>:9090, which pointed at a loopback-only service before.
# Phase B (BACKLOG.md) puts Caddy with TLS and authentication in front.
#
# Scrape targets come from the inventory (lib/monitoring.nix,
# `fleet.monitoring.targets`); nothing here names a host. Jobs:
#   node              - node_exporter of every machine of class server/virtual
#   smartctl          - smartctl_exporter of every machine of class server
#   blackbox-icmp     - ping of monitored machines and of devices with
#                       `monitoring.ping = true` (hosts/devices/)
#   blackbox-http     - pages from hosts/websites.nix
#   blackbox-internet - ping of public DNS resolvers (InternetDown)
#   pve               - Proxmox API of devices with `monitoring.pve = true`,
#                       through the local pve exporter (pve.nix)
#   cadvisor          - containers: cAdvisor on devices with
#                       `monitoring.cadvisor = true` (Docker) and on this
#                       server when it runs Podman (cadvisor.nix); label
#                       `runtime` = docker / podman
#   nvidia, incus     - only on a monitoring server that has them (altair)
#   prometheus, alertmanager, blackbox - the monitoring stack itself
#
# Alert rules: alert-rules.nix. Alerts go to Alertmanager (alertmanager.nix).
{
  config,
  lib,
  pkgs,
  host,
  ...
}: let
  targets = config.fleet.monitoring.targets;

  # One static_config per target, so each keeps its own labels.
  staticConfigs = map (x: {
    targets = [x.address];
    inherit (x) labels;
  });

  # Multi-target pattern (blackbox, pve): the target becomes the ?target=
  # parameter and the scrape goes to the local exporter.
  viaExporter = exporter: [
    {
      source_labels = ["__address__"];
      target_label = "__param_target";
    }
    {
      target_label = "__address__";
      replacement = exporter;
    }
  ];

  blackboxExporter = "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}";
  blackboxJob = name: module: interval: targetList: {
    job_name = name;
    scrape_interval = interval;
    metrics_path = "/probe";
    params.module = [module];
    static_configs = staticConfigs targetList;
    relabel_configs = viaExporter blackboxExporter;
  };

  # Public resolvers for the internet check.
  internetTargets = [
    {
      address = "1.1.1.1";
      labels.instance = "cloudflare-dns";
    }
    {
      address = "9.9.9.9";
      labels.instance = "quad9-dns";
    }
  ];

  localJob = name: port: labels: {
    job_name = name;
    static_configs = [
      {
        targets = ["127.0.0.1:${toString port}"];
        # instance = host name, like the generated jobs, so dashboards show
        # "altair" instead of 127.0.0.1:<port>.
        labels =
          {
            instance = host.name;
            host = host.name;
          }
          // labels;
      }
    ];
  };

  nvidiaEnabled = config.services.prometheus.exporters.nvidia-gpu.enable or false;

  # cAdvisor targets: Docker hosts from the inventory plus this server's own
  # cAdvisor for Podman.
  cadvisorTargets =
    targets.cadvisor
    ++ lib.optional config.services.cadvisor.enable {
      address = "127.0.0.1:${toString config.services.cadvisor.port}";
      labels = {
        instance = host.name;
        host = host.name;
        runtime = "podman";
      };
    };
  incusEnabled = config.virtualisation.incus.enable or false;

  rulesFile = pkgs.writeText "fleet-alert-rules.yml" (builtins.toJSON (import ./alert-rules.nix));
in {
  services.prometheus = {
    enable = true;
    listenAddress = "0.0.0.0"; # firewall below: LAN interface only
    port = 9090;
    webExternalUrl = "http://${host.name}.${config.networking.domain}:${toString config.services.prometheus.port}";
    retentionTime = "90d";
    checkConfig = "syntax-only";

    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    alertmanagers = [
      {
        static_configs = [
          {targets = ["127.0.0.1:${toString config.services.prometheus.alertmanager.port}"];}
        ];
      }
    ];

    ruleFiles = [rulesFile];

    scrapeConfigs =
      [
        {
          job_name = "node";
          static_configs = staticConfigs targets.node;
        }
        {
          job_name = "smartctl";
          scrape_interval = "60s";
          static_configs = staticConfigs targets.smartctl;
        }
        (blackboxJob "blackbox-icmp" "icmp" "30s" targets.ping)
        (blackboxJob "blackbox-http" "http_2xx" "30s" targets.websites)
        (blackboxJob "blackbox-internet" "icmp" "30s" internetTargets)

        (localJob "prometheus" config.services.prometheus.port {})
        (localJob "alertmanager" config.services.prometheus.alertmanager.port {})
        (localJob "blackbox" config.services.prometheus.exporters.blackbox.port {})
      ]
      # Proxmox: one API read per scrape and one more per guest (config
      # collector), hence the longer interval and timeout.
      ++ lib.optional (targets.pve != []) {
        job_name = "pve";
        scrape_interval = "30s";
        scrape_timeout = "20s";
        metrics_path = "/pve";
        params = {
          cluster = ["1"];
          node = ["1"];
        };
        static_configs = staticConfigs targets.pve;
        relabel_configs = viaExporter "127.0.0.1:${toString config.services.prometheus.exporters.pve.port}";
      }
      ++ lib.optional (cadvisorTargets != []) {
        job_name = "cadvisor";
        scrape_interval = "30s";
        static_configs = staticConfigs cadvisorTargets;
      }
      ++ lib.optional nvidiaEnabled
      (localJob "nvidia" config.services.prometheus.exporters.nvidia-gpu.port {role = "gpu";})
      # Incus container/VM metrics. Requires the metrics listener on
      # 127.0.0.1:9101 (modules/servers/incus/default.nix) and the client
      # certificate in /var/lib/prometheus-incus/.
      ++ lib.optional incusEnabled {
        job_name = "incus";
        scrape_interval = "30s";
        scheme = "https";
        metrics_path = "/1.0/metrics";
        tls_config = {
          insecure_skip_verify = true;
          cert_file = "/var/lib/prometheus-incus/metrics.crt";
          key_file = "/var/lib/prometheus-incus/metrics.key";
        };
        static_configs = [
          {
            targets = ["127.0.0.1:9101"];
            labels = {
              instance = host.name;
              host = host.name;
              role = "incus";
            };
          }
        ];
      };
  };

  # Web UI from the LAN interface only (`lan.interface` in
  # hosts/machines/<host>.nix), not from Incus containers (incusbr0).
  networking.firewall.interfaces.${host.lan.interface}.allowedTCPPorts = [config.services.prometheus.port];
}
