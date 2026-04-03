# modules/servers/monitoring/prometheus.nix
#
# Prometheus TSDB. Listens on loopback only — Grafana scrapes via localhost.
# Incus metrics require metricsAddress to be set in incus.nix (see comment below).
# Retention 90 days — enough baseline for GPU comparison across burn-in runs.
{...}: {
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    retentionTime = "90d";
    checkConfig = "syntax-only";

    globalConfig.scrape_interval = "15s";

    scrapeConfigs = [
      # ── Host hardware + OS ──────────────────────────────────────────────────
      {
        job_name = "altair-node";
        static_configs = [
          {
            targets = ["127.0.0.1:9100"];
            labels = {
              host = "altair";
              role = "baremetal";
            };
          }
        ];
      }

      # ── Incus container/VM metrics ──────────────────────────────────────────
      # Requires: virtualisation.incus.metrics.enable = true in incus.nix
      # and metricsAddress = "127.0.0.1:9101"
      {
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
              host = "altair";
              role = "incus";
            };
          }
        ];
      }

      # ── GPU metrics ─────────────────────────────────────────────────────────
      # Phase C: uncomment when nvidia-exporter.nix is added
      {
        job_name = "altair-nvidia";
        static_configs = [
          {
            targets = ["127.0.0.1:9835"];
            labels = {
              host = "altair";
              role = "gpu";
            };
          }
        ];
      }

      # OPNsense metrics
      {
        job_name = "opnsesne firewall";
        static_configs = [
          {
            trgets = ["192.168.50.149:9100"];
            labels = {
              host = "opnsesne";
              role = "firewall";
            };
          }
        ];
      }
    ];

    # Alerting rules
    rules = [
      ''
        groups:
          - name: altair
            rules:

              - alert: NodeExporterDown
                expr: up{job="altair-node"} == 0
                for: 2m
                labels: { severity: critical }
                annotations:
                  summary: "Altair node exporter unreachable"

              - alert: DataDiskLow
                expr: >
                  node_filesystem_avail_bytes{job="altair-node",mountpoint="/mnt/data"}
                  / node_filesystem_size_bytes{job="altair-node",mountpoint="/mnt/data"} < 0.10
                for: 15m
                labels: { severity: warning }
                annotations:
                  summary: "Data disk < 10% free on altair"

              - alert: CPUTempHigh
                expr: node_hwmon_temp_celsius{job="altair-node",chip=~".*k10temp.*",sensor="Tctl"} > 85
                for: 5m
                labels: { severity: warning }
                annotations:
                  summary: "CPU Tctl above 85°C"

              - alert: SystemdUnitFailed
                expr: node_systemd_unit_state{job="altair-node",state="failed"} == 1
                for: 1m
                labels: { severity: warning }
                annotations:
                  summary: "Systemd unit {{ $labels.name }} is in failed state"

              - alert: GPUTempHigh
                expr: nvidia_smi_temperature_gpu > 85
                for: 5m
                labels: { severity: warning }
                annotations:
                  summary: "GPU {{ $labels.gpu }} above 85°C on altair"

              - alert: GPUMemoryHigh
                expr: >
                 nvidia_smi_memory_used_bytes / nvidia_smi_memory_total_bytes > 0.95
                for: 10m
                labels: { severity: warning }
                annotations:
                  summary: "GPU {{ $labels.gpu }} VRAM > 95% on altair"
      ''
    ];
  };
}
