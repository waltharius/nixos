# modules/servers/monitoring/alert-rules.nix
#
# Prometheus alerting rules, as Nix data. prometheus.nix writes them to a
# rule file (JSON is valid YAML). Thresholds are at the top.
#
# Labels used by the rules come from the scrape targets (lib/monitoring.nix):
#   host      - machine or device name
#   class     - server or virtual (node_exporter targets)
#   baremetal - "true" for class server: hardware rules apply only there
#   site      - page name from hosts/websites.nix
#
# Severities:
#   critical - something is down or data is at risk
#   warning  - needs attention soon
#   info     - for the record (reboots)
# Every severity is e-mailed; HostDown suppresses the other alerts of the
# same host (inhibit rule in alertmanager.nix). Expressions follow
# https://samber.github.io/awesome-prometheus-alerts/ where one fits.
#
# Each alert has `summary` (subject line) and `description` (details).
# Silence an alert for maintenance in Grafana: Alerting -> Silences
# (Alertmanager data source), see docs/MONITORING.md.
let
  t = {
    diskFreeWarning = 0.10; # fraction of the filesystem
    diskFreeCritical = 0.05;
    cpuBusy = 0.90; # average over cpuBusyWindow
    cpuBusyWindow = "12h";
    gpuBusy = 0.90;
    hwmonTemp = 85; # degrees Celsius, any hwmon sensor on bare metal
    gpuTemp = 85;
    diskTemp = 65; # S.M.A.R.T. temperature
    nvmeWear = 80; # percentage used
    clockOffset = 0.05; # seconds
    websiteSlow = 3; # seconds
    certDays = 14;
    scrubMaxAgeDays = 40; # scrub runs monthly
  };

  rule = alert: expr: for: severity: summary: description: {
    inherit alert expr for;
    labels.severity = severity;
    annotations = {inherit summary description;};
  };

  hostRef = "{{ $labels.host }}";
in {
  groups = [
    {
      name = "availability";
      rules = [
        (rule "HostDown" ''probe_success{job="blackbox-icmp"} == 0'' "2m" "critical"
          "${hostRef} is down"
          "${hostRef} ({{ $labels.kind }}) has not answered ping for 2 minutes. The other alerts of this host are suppressed until it answers again.")

        (rule "NodeExporterDown" ''up{job="node"} == 0'' "5m" "warning"
          "node_exporter on ${hostRef} is unreachable"
          "Prometheus cannot scrape node_exporter on ${hostRef}. If the host answers ping, the exporter or the firewall rule is the problem: systemctl status prometheus-node-exporter (NixOS) or node_exporter (devices; reinstall with nix run .#fleet).")

        (rule "SmartctlExporterDown" ''up{job="smartctl"} == 0'' "10m" "warning"
          "smartctl_exporter on ${hostRef} is unreachable"
          "Prometheus cannot scrape smartctl_exporter on ${hostRef}: systemctl status prometheus-smartctl-exporter (NixOS) or smartctl_exporter (devices; reinstall with nix run .#fleet).")

        (rule "InternetDown" ''max(probe_success{job="blackbox-internet"}) == 0'' "3m" "critical"
          "Internet connection is down"
          "None of the public DNS resolvers answers ping from the monitoring server. This e-mail can only be delivered once the connection is back (Postfix retries); compare the times in it to see how long the outage lasted.")

        (rule "HostRebooted" ''changes(node_boot_time_seconds[15m]) > 0'' "0m" "info"
          "${hostRef} was restarted"
          "${hostRef} booted within the last 15 minutes. If nobody restarted it, check for a power failure.")
      ];
    }

    {
      name = "websites";
      rules = [
        (rule "WebsiteDown" ''probe_success{job="blackbox-http"} == 0'' "5m" "critical"
          "Website {{ $labels.site }} is down"
          "{{ $labels.site }} has not answered with a 2xx status for 5 minutes (hosts/websites.nix).")

        (rule "WebsiteSlow" ''probe_duration_seconds{job="blackbox-http"} > ${toString t.websiteSlow}'' "10m" "warning"
          "Website {{ $labels.site }} is slow"
          "{{ $labels.site }} took {{ $value | humanizeDuration }} to answer (threshold ${toString t.websiteSlow} s) for 10 minutes.")

        (rule "WebsiteCertificateExpiring" ''probe_ssl_earliest_cert_expiry{job="blackbox-http"} - time() < ${toString t.certDays} * 86400'' "1h" "warning"
          "Certificate of {{ $labels.site }} expires soon"
          "The TLS certificate of {{ $labels.site }} expires in {{ $value | humanizeDuration }}.")
      ];
    }

    {
      name = "resources";
      rules = [
        (rule "DiskSpaceLow" ''
            node_filesystem_avail_bytes{job="node"} / node_filesystem_size_bytes{job="node"} < ${toString t.diskFreeWarning}
            and node_filesystem_readonly{job="node"} == 0
          '' "15m" "warning"
          "Disk space low on ${hostRef} ({{ $labels.mountpoint }})"
          "{{ $labels.mountpoint }} on ${hostRef} has {{ $value | humanizePercentage }} free.")

        (rule "DiskSpaceCritical" ''
            node_filesystem_avail_bytes{job="node"} / node_filesystem_size_bytes{job="node"} < ${toString t.diskFreeCritical}
            and node_filesystem_readonly{job="node"} == 0
          '' "5m" "critical"
          "Disk almost full on ${hostRef} ({{ $labels.mountpoint }})"
          "{{ $labels.mountpoint }} on ${hostRef} has {{ $value | humanizePercentage }} free.")

        # Fast growth: full within 24 hours at the rate of the last 6 hours.
        # Only below 25 % free, so a large but steady disk does not trigger.
        (rule "DiskWillFillIn24h" ''
            predict_linear(node_filesystem_avail_bytes{job="node"}[6h], 24 * 3600) < 0
            and node_filesystem_avail_bytes{job="node"} / node_filesystem_size_bytes{job="node"} < 0.25
            and node_filesystem_readonly{job="node"} == 0
          '' "1h" "warning"
          "Disk on ${hostRef} ({{ $labels.mountpoint }}) fills up within 24 h"
          "At the rate of the last 6 hours {{ $labels.mountpoint }} on ${hostRef} is full within a day.")

        # Read-only by design, not after errors: nullfs (FreeBSD bind mounts,
        # pfSense's unbound chroot), squashfs and iso9660 images, ubifs (the
        # ASUS routers' root filesystem image).
        (rule "FilesystemReadOnly" ''node_filesystem_readonly{job="node",mountpoint!~"/nix/store|/boot.*",fstype!~"nullfs|squashfs|iso9660|ubifs"} == 1'' "5m" "critical"
          "Filesystem {{ $labels.mountpoint }} on ${hostRef} is read-only"
          "btrfs switches a filesystem to read-only after errors. Check dmesg and journalctl -k on ${hostRef}.")

        # rate() divides by the whole window: for a host scraped for less
        # than the window it reads as almost no idle time, i.e. ~100 % busy
        # (every new device fired on 2026-10-03). Hence the guard: the host
        # must already have been scraped one window ago.
        (rule "CpuBusy12h" ''
            1 - avg by (host) (rate(node_cpu_seconds_total{job="node",mode="idle"}[${t.cpuBusyWindow}])) > ${toString t.cpuBusy}
            and on (host) (up{job="node"} offset ${t.cpuBusyWindow})
          '' "5m" "warning"
          "CPU on ${hostRef} busy for ${t.cpuBusyWindow}"
          (
            "The CPU of ${hostRef} was {{ $value | humanizePercentage }} busy on average over the last ${t.cpuBusyWindow}."
            # GPU load of the same host for comparison (hosts with the NVIDIA exporter).
            + "{{ with printf \"avg(nvidia_smi_utilization_gpu_ratio{host='%s'})\" $labels.host | query }}{{ if . }} GPU utilisation right now: {{ . | first | value | humanizePercentage }}.{{ end }}{{ end }}"
          ))

        (rule "OomKill" ''increase(node_vmstat_oom_kill{job="node"}[30m]) > 0'' "0m" "warning"
          "Out-of-memory kill on ${hostRef}"
          "The kernel killed a process on ${hostRef} because memory ran out. journalctl -k | grep -i oom shows which one.")
      ];
    }

    {
      name = "services-and-time";
      rules = [
        (rule "SystemdUnitFailed" ''node_systemd_unit_state{job="node",state="failed"} == 1'' "5m" "warning"
          "Service {{ $labels.name }} failed on ${hostRef}"
          "systemctl status {{ $labels.name }} and journalctl -u {{ $labels.name }} on ${hostRef}.")

        # Network devices (ASUS firmware's NTP client) do not maintain the
        # kernel's sync status; for them, and everywhere, the clock is also
        # compared with the Prometheus server's time at scrape (> 2 s off).
        (rule "ClockNotSynchronised" ''
            abs(node_timex_offset_seconds{job="node"}) > ${toString t.clockOffset}
            or node_timex_sync_status{job="node",category!="network"} == 0
            or abs(node_time_seconds{job="node"} - timestamp(node_time_seconds{job="node"})) > 2
          '' "15m" "warning"
          "Clock of ${hostRef} is not synchronised"
          "The clock of ${hostRef} is off by more than ${toString t.clockOffset} s, the kernel reports it as not synchronised, or it differs from the monitoring server's clock by more than 2 s. timedatectl status on ${hostRef}.")

        (rule "TextfileCollectorError" ''node_textfile_scrape_error{job="node"} == 1'' "15m" "warning"
          "Unreadable textfile metrics on ${hostRef}"
          "node_exporter on ${hostRef} cannot parse a .prom file in its textfile directory; a job wrote a broken file.")
      ];
    }

    {
      name = "hardware";
      rules = [
        (rule "HostTemperatureHigh" ''node_hwmon_temp_celsius{job="node",baremetal="true"} > ${toString t.hwmonTemp}'' "5m" "warning"
          "Temperature high on ${hostRef} ({{ $labels.chip }} {{ $labels.sensor }})"
          "Sensor {{ $labels.chip }}/{{ $labels.sensor }} on ${hostRef} reads {{ $value }} °C (threshold ${toString t.hwmonTemp} °C).")

        (rule "HostTemperatureCriticalAlarm" ''node_hwmon_temp_crit_alarm_celsius{job="node",baremetal="true"} == 1'' "0m" "critical"
          "Critical temperature alarm on ${hostRef}"
          "Sensor {{ $labels.chip }}/{{ $labels.sensor }} on ${hostRef} raised its critical temperature alarm.")

        (rule "GpuTemperatureHigh" ''nvidia_smi_temperature_gpu > ${toString t.gpuTemp}'' "5m" "warning"
          "GPU {{ $labels.uuid }} on ${hostRef} above ${toString t.gpuTemp} °C"
          "GPU temperature {{ $value }} °C on ${hostRef}.")

        (rule "GpuBusy12h" ''avg_over_time(nvidia_smi_utilization_gpu_ratio[12h]) > ${toString t.gpuBusy}'' "5m" "warning"
          "GPU {{ $labels.uuid }} on ${hostRef} busy for 12 h"
          "Average GPU utilisation over the last 12 hours: {{ $value | humanizePercentage }}. Compare with CpuBusy12h to see which part is loaded.")

        (rule "SmartHealthFailed" ''smartctl_device_smart_status == 0'' "0m" "critical"
          "Disk {{ $labels.device }} on ${hostRef} fails its S.M.A.R.T. check"
          "The drive reports that it is failing. Make sure the backups are current and replace it.")

        (rule "DiskTemperatureHigh" ''smartctl_device_temperature{temperature_type="current"} > ${toString t.diskTemp}'' "10m" "warning"
          "Disk {{ $labels.device }} on ${hostRef} is hot"
          "Drive temperature {{ $value }} °C (threshold ${toString t.diskTemp} °C).")

        (rule "NvmeCriticalWarning" ''smartctl_device_critical_warning > 0'' "0m" "critical"
          "NVMe {{ $labels.device }} on ${hostRef} reports a critical warning"
          "smartctl -a /dev/{{ $labels.device }} on ${hostRef} shows which one.")

        (rule "NvmeWearHigh" ''smartctl_device_percentage_used > ${toString t.nvmeWear}'' "1h" "warning"
          "NVMe {{ $labels.device }} on ${hostRef} is {{ $value }} % worn"
          "The drive has used {{ $value }} % of its rated endurance.")

        (rule "BtrfsScrubErrors" ''btrfs_scrub_errors > 0'' "0m" "warning"
          "btrfs scrub found {{ $labels.type }} on ${hostRef} ({{ $labels.mountpoint }})"
          "The last scrub of {{ $labels.mountpoint }} counted {{ $value }} {{ $labels.type }}. btrfs scrub status {{ $labels.mountpoint }} and btrfs device stats {{ $labels.mountpoint }} on ${hostRef}.")

        (rule "BtrfsScrubUncorrectable" ''btrfs_scrub_errors{type="uncorrectable_errors"} > 0'' "0m" "critical"
          "btrfs scrub found uncorrectable errors on ${hostRef} ({{ $labels.mountpoint }})"
          "Data on {{ $labels.mountpoint }} is damaged and could not be repaired from a second copy. dmesg names the affected files; restore them from a backup.")

        (rule "BtrfsScrubStale" ''
            btrfs_scrub_stats_available == 1
            and time() - btrfs_scrub_started_timestamp_seconds > ${toString t.scrubMaxAgeDays} * 86400
          '' "1h" "warning"
          "No btrfs scrub on ${hostRef} ({{ $labels.mountpoint }}) for ${toString t.scrubMaxAgeDays} days"
          "The monthly scrub did not run: systemctl list-timers 'btrfs-scrub-*' on ${hostRef}.")
      ];
    }

    # Proxmox VE through the pve exporter (job pve, pve.nix). Guest metrics
    # carry only `id` (qemu/<vmid>, lxc/<vmid>); the guest's name is joined
    # from pve_guest_info. `host` is the Proxmox host, so HostDown on it
    # suppresses these alerts. Mind PromQL precedence: `*` binds tighter
    # than `==` and `and`, hence the parentheses.
    {
      name = "proxmox";
      rules = [
        (rule "PveExporterDown" ''up{job="pve"} == 0'' "5m" "warning"
          "Proxmox API of ${hostRef} cannot be read"
          "The pve exporter on the monitoring server fails to read the Proxmox API of ${hostRef}: exporter stopped, token revoked or expired, or the pveproxy certificate no longer verifies against the FreeIPA CA. journalctl -u prometheus-pve-exporter on the monitoring server.")

        # Only guests set to start at boot: a guest kept off on purpose has
        # onboot = 0 and is ignored. Templates never run and are skipped.
        (rule "PveGuestDown" ''
            (
              (pve_up{job="pve",id=~"(qemu|lxc)/.*"} == 0)
              and on (host, id) (pve_onboot_status{job="pve"} == 1)
            )
            * on (host, id) group_left (name) pve_guest_info{job="pve",template!="1"}
          '' "5m" "warning"
          "Proxmox guest {{ $labels.name }} ({{ $labels.id }}) on ${hostRef} is not running"
          "{{ $labels.id }} ({{ $labels.name }}) is set to start at boot but has not been running for 5 minutes. Check it in the Proxmox web UI or with qm status / pct status on ${hostRef}.")

        # Skipped: templates, and guests with the Proxmox tag `nobackup`
        # (a guest deliberately left out of every backup job).
        (rule "PveGuestNotBackedUp" ''
            pve_not_backed_up_info{job="pve"}
            * on (host, id) group_left (name) pve_guest_info{job="pve",template!="1",tags!~"(.*;)?nobackup(;.*)?"}
          '' "1h" "warning"
          "Proxmox guest {{ $labels.name }} ({{ $labels.id }}) is in no backup job"
          "No backup job on ${hostRef} covers {{ $labels.id }} ({{ $labels.name }}). Add it to a job under Datacenter -> Backup, give it the tag nobackup if it is left out on purpose, or remove the guest if it is not needed.")

        # Storage size 0 means inactive or unavailable storage: skipped.
        (rule "PveStorageLow" ''
            1 - pve_disk_usage_bytes{job="pve",id=~"storage/.*"} / pve_disk_size_bytes{job="pve",id=~"storage/.*"} < ${toString t.diskFreeWarning}
            and on (host, id) pve_disk_size_bytes{job="pve",id=~"storage/.*"} > 0
          '' "15m" "warning"
          "Proxmox storage {{ $labels.id }} on ${hostRef} is filling up"
          "{{ $labels.id }} has {{ $value | humanizePercentage }} free.")

        (rule "PveStorageCritical" ''
            1 - pve_disk_usage_bytes{job="pve",id=~"storage/.*"} / pve_disk_size_bytes{job="pve",id=~"storage/.*"} < ${toString t.diskFreeCritical}
            and on (host, id) pve_disk_size_bytes{job="pve",id=~"storage/.*"} > 0
          '' "5m" "critical"
          "Proxmox storage {{ $labels.id }} on ${hostRef} is almost full"
          "{{ $labels.id }} has {{ $value | humanizePercentage }} free.")
      ];
    }

    # UPS through the nut exporter (job nut, nut.nix). `host` is the device
    # running the NUT server (pfSense), so HostDown on it suppresses the
    # warnings. Status flags as NUT reports them: OB on battery, LB battery
    # low, RB replace battery, OVER overload.
    {
      name = "ups";
      rules = [
        (rule "UpsOnBattery" ''network_ups_tools_ups_status{job="nut",flag="OB"} == 1'' "1m" "critical"
          "UPS {{ $labels.ups }} on ${hostRef} runs on battery"
          "Mains power is gone. Charge and estimated runtime: see the UPS dashboard. At low battery NUT on ${hostRef} shuts down the connected machines.")

        (rule "UpsBatteryLow" ''network_ups_tools_ups_status{job="nut",flag="LB"} == 1'' "0m" "critical"
          "UPS {{ $labels.ups }} on ${hostRef}: battery low"
          "The UPS reports a low battery; shutdown of the connected machines is imminent or under way.")

        (rule "UpsReplaceBattery" ''network_ups_tools_ups_status{job="nut",flag="RB"} == 1'' "1h" "warning"
          "UPS {{ $labels.ups }} on ${hostRef}: replace the battery"
          "The UPS's self-test reports a worn-out battery.")

        (rule "UpsOverload" ''network_ups_tools_ups_status{job="nut",flag="OVER"} == 1'' "0m" "critical"
          "UPS {{ $labels.ups }} on ${hostRef} is overloaded"
          "The connected load exceeds what the UPS can carry.")

        (rule "UpsLoadHigh" ''network_ups_tools_ups_load{job="nut"} > 80'' "15m" "warning"
          "UPS {{ $labels.ups }} on ${hostRef} at {{ $value }} % load"
          "Load above 80 % for 15 minutes shortens the runtime on battery.")

        (rule "UpsUnreachable" ''up{job="nut"} == 0'' "5m" "warning"
          "UPS on ${hostRef} cannot be read"
          "The nut exporter on the monitoring server cannot read the UPS from upsd on ${hostRef} (port 3493): upsd stopped, not listening on the LAN, or the UPS name in hosts/devices/ is wrong. journalctl -u prometheus-nut-exporter on the monitoring server.")
      ];
    }

    # Containers (cAdvisor, job cadvisor). Stopped containers simply
    # disappear from cAdvisor's metrics, so there is no "container down"
    # rule yet; that needs a list of expected containers.
    {
      name = "containers";
      rules = [
        (rule "CadvisorDown" ''up{job="cadvisor"} == 0'' "5m" "warning"
          "Container metrics of ${hostRef} are missing"
          "cAdvisor on ${hostRef} ({{ $labels.runtime }}) does not answer. Docker hosts: systemctl status cadvisor on the device, reinstall with nix run .#fleet (monitoring apply). Monitoring server: systemctl status cadvisor.")
      ];
    }

    {
      name = "monitoring";
      rules = [
        # Always firing. Alertmanager sends it to healthchecks.io every few
        # minutes; when it stops arriving, healthchecks.io e-mails on its
        # own. This catches the case where the monitoring server itself is
        # down (power failure, LUKS waiting for the passphrase).
        {
          alert = "Watchdog";
          expr = "vector(1)";
          labels.severity = "none";
          annotations.summary = "Always firing; proves that the alerting pipeline works end to end.";
        }

        (rule "MonitoringTargetDown" ''up{job=~"prometheus|alertmanager|blackbox"} == 0'' "5m" "critical"
          "{{ $labels.job }} on the monitoring server is down"
          "Prometheus cannot scrape {{ $labels.job }}.")

        (rule "AlertmanagerNotificationsFailing" ''rate(alertmanager_notifications_failed_total[10m]) > 0'' "10m" "critical"
          "Alertmanager cannot deliver {{ $labels.integration }} notifications"
          "Notifications through {{ $labels.integration }} fail. For e-mail: journalctl -u alertmanager and journalctl -u postfix, mailq.")

        (rule "PrometheusRuleEvaluationFailures" ''increase(prometheus_rule_evaluation_failures_total[10m]) > 0'' "0m" "warning"
          "Prometheus fails to evaluate alert rules"
          "Some alert rules cannot be evaluated; their alerts would never fire. Check Status -> Rules in Prometheus or Alerting -> Alert rules in Grafana.")

        (rule "PrometheusConfigReloadFailed" ''prometheus_config_last_reload_successful == 0'' "5m" "warning"
          "Prometheus could not load its configuration"
          "journalctl -u prometheus on the monitoring server.")
      ];
    }
  ];
}
