# Monitoring

Prometheus, Alertmanager and Grafana run on the monitoring server named in
`hosts/fleet.nix` (`monitoring.server`, currently altair). Everything about
which hosts are watched is derived from the inventory (`lib/monitoring.nix`);
no module names a host.

## What is monitored

| What | How | Where it comes from |
| ---- | --- | ------------------- |
| NixOS machines of class `server` and `virtual` | node_exporter (OS metrics, systemd units, textfile metrics) and ping | `hosts/machines/*.nix`, automatically |
| NixOS machines of class `server` (bare metal) | additionally smartctl_exporter (disks), temperatures, monthly btrfs scrub | same, automatically |
| Workstations (laptops) | not monitored | - |
| Devices without NixOS | ping (up/down); full metrics follow in stage 5b | `monitoring.ping = true` in `hosts/devices/<name>.nix` |
| Web pages | HTTP probe: status, response time, certificate expiry | `hosts/websites.nix` |
| Internet connection | ping of 1.1.1.1 and 9.9.9.9 | `modules/servers/monitoring/prometheus.nix` |
| GPUs (altair) | nvidia_gpu_exporter | `hosts/physical/altair/configuration.nix` |
| The monitoring itself | Watchdog to healthchecks.io, scrape and notification failures | `alert-rules.nix`, `alertmanager.nix` |

Exporters listen on all addresses; the firewall of each host lets only the
monitoring server's address reach the exporter ports (9100 node, 9633
smartctl). The monitoring stack itself listens on loopback, except Grafana
(port 3000, LAN interface).

## Files

| File | Contents |
| ---- | -------- |
| `lib/monitoring.nix` | roles (what each host gets), scrape targets from the inventory, exporter firewall rule |
| `modules/servers/monitoring/node-exporter.nix` | node_exporter on monitored hosts, textfile directory |
| `modules/servers/monitoring/smartctl.nix` | disk S.M.A.R.T. on bare metal |
| `modules/servers/monitoring/btrfs-scrub.nix` | monthly scrub per btrfs device, result as textfile metrics |
| `modules/servers/monitoring/default.nix` | the monitoring server stack (imports the files below) |
| `modules/servers/monitoring/prometheus.nix` | Prometheus, scrape jobs |
| `modules/servers/monitoring/alert-rules.nix` | alert rules and thresholds |
| `modules/servers/monitoring/alertmanager.nix` | routing, e-mail, Watchdog webhook, inhibition |
| `modules/servers/monitoring/mail.nix` | send-only Postfix |
| `modules/servers/monitoring/blackbox.nix` | ping and HTTP probes |
| `modules/servers/monitoring/grafana.nix` | Grafana, data sources, dashboards |
| `modules/servers/monitoring/nvidia-exporter.nix` | GPU metrics (altair only) |

## Where to look

- **Grafana** (`http://192.168.50.150:3000`):
  - Alerting -> Alert rules: every rule with its state. The "State" view
    lists what is firing, like the problem list in Checkmk. This works
    even when e-mail does not.
  - Alerting -> Silences (choose the "Alertmanager" data source at the
    top): mute alerts during maintenance.
  - Dashboards: Node Exporter Full (per host), Prometheus Blackbox
    (ping and websites), NVIDIA GPU.
- **E-mail**: every alert, when it fires and when it is resolved, to
  `monitoring.mail.to` in `hosts/fleet.nix`. A still-firing alert is
  repeated every 12 hours.
- **healthchecks.io**: e-mails on its own when the Watchdog pings stop,
  i.e. when the monitoring server, Alertmanager or the internet
  connection is down. Nothing on the monitoring server can tell you that
  it is down itself.

## Alerts

Defined in `modules/servers/monitoring/alert-rules.nix` (thresholds at the
top of the file). Severity `critical`, `warning` or `info`; all are
e-mailed. While a host does not answer ping (HostDown), its warnings and
info alerts are suppressed.

| Group | Alerts |
| ----- | ------ |
| availability | HostDown, NodeExporterDown, SmartctlExporterDown, InternetDown, HostRebooted |
| websites | WebsiteDown, WebsiteSlow, WebsiteCertificateExpiring |
| resources | DiskSpaceLow, DiskSpaceCritical, DiskWillFillIn24h, FilesystemReadOnly, CpuBusy12h, OomKill |
| services and time | SystemdUnitFailed, ClockNotSynchronised, TextfileCollectorError |
| hardware (bare metal) | HostTemperatureHigh, HostTemperatureCriticalAlarm, GpuTemperatureHigh, GpuBusy12h, SmartHealthFailed, DiskTemperatureHigh, NvmeCriticalWarning, NvmeWearHigh, BtrfsScrubErrors, BtrfsScrubUncorrectable, BtrfsScrubStale |
| monitoring | Watchdog, MonitoringTargetDown, AlertmanagerNotificationsFailing, PrometheusRuleEvaluationFailures, PrometheusConfigReloadFailed |

CpuBusy12h includes the current GPU utilisation of the same host, and
GpuBusy12h is a separate alert, so a long LLM job shows which part is
loaded.

## Everyday tasks

| Task | Steps |
| ---- | ----- |
| Monitor a new NixOS server or VM | `nix run .#new-host` (class `server` or `virtual`), deploy the host, then deploy the monitoring server (`colmena apply --on altair`) so Prometheus learns the new target |
| Ping a device | add `monitoring.ping = true;` to `hosts/devices/<name>.nix`, deploy the monitoring server |
| Stop pinging a device | remove the line (or the whole file), deploy the monitoring server |
| Add a web page | add an entry to `hosts/websites.nix`, deploy the monitoring server |
| Change a threshold | edit the `t` set at the top of `alert-rules.nix`, deploy the monitoring server |
| Silence an alert | Grafana -> Alerting -> Silences -> data source "Alertmanager" -> New silence |
| Start a scrub now | `sudo systemctl start btrfs-scrub-mnt-data.service` (or `btrfs-scrub--.service` for `/`; `systemctl list-units 'btrfs-scrub-*'` lists them), then `sudo systemctl start btrfs-scrub-metrics.service` |
| Export a result through the textfile collector | write `<name>.prom` (Prometheus text format) to `/var/lib/node-exporter-textfile/`: write a temporary file in the same directory, `chmod 0644`, then `mv` it over the old one, so node_exporter never reads half a file. Example: `btrfs-scrub.nix` |

## Alert e-mail

Alertmanager hands mail to a send-only Postfix on the monitoring server
(`mail.nix`), which delivers straight to the recipient's mail server. While
the internet is down Postfix queues mail and retries.

Test the path without waiting for an alert:

```sh
# On the monitoring server: Postfix alone
printf 'Subject: postfix test\n\ntest from altair\n' | sendmail -f alertmanager@altair.home.lan alerts.pavement456@passmail.net
mailq                      # empty once delivered
journalctl -u postfix -n 50   # 'status=sent' or the reason for a rejection

# Through Alertmanager: a test alert that resolves after 5 minutes
nix shell nixpkgs#prometheus-alertmanager -c amtool --alertmanager.url=http://127.0.0.1:9093 \
  alert add TestAlert severity=warning host=altair --annotation=summary='Test alert, ignore'
```

If the receiving server rejects or spam-files the mail (a home address has
no SPF record and no matching reverse DNS), relay through an authenticated
mailbox instead (BACKLOG.md, "Alert mail relay").

## Watchdog (healthchecks.io)

The rule `Watchdog` always fires. Alertmanager sends it every 2 minutes as
a webhook to a healthchecks.io check; when the pings stop, healthchecks.io
e-mails its account address.

Setup (once):

1. On healthchecks.io create a check: period 5 minutes, grace 5 minutes,
   e-mail integration to the alert address.
2. Copy its ping URL (`https://hc-ping.com/<uuid>`) into
   `secrets/altair.yaml` as `healthchecks-watchdog-url`
   (`sops secrets/altair.yaml`). The URL is a secret: anyone who knows it
   can keep the check green.
3. Deploy altair. The check turns green within a few minutes.

Test: `sudo systemctl stop alertmanager` on altair; healthchecks.io should
e-mail within about 10 minutes. Start it again afterwards.

## Grafana

Everything in Grafana is provisioned from `grafana.nix`; nothing is
configured by hand in the UI. `grafana.db` therefore holds nothing that is
not recreated at start, and metrics live in Prometheus, not in Grafana.
Grafana encrypts secrets in its database with `secret_key`
(`grafana-secret-key` in `secrets/altair.yaml`); a new key needs an empty
database. Procedure: stop grafana, move `/var/lib/grafana/data/grafana.db`
aside, change the key with sops, deploy (as in stage 5a, CHANGELOG.md).
