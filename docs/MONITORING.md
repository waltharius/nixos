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
| Proxmox VE (host, VMs, LXC containers, storage) | pve exporter on the monitoring server reading the Proxmox API with a read-only token; nothing installed on Proxmox | `monitoring.pve = true` in `hosts/devices/<name>.nix` |
| Devices without NixOS that run Linux with systemd (Proxmox host and guests, Raspberry Pis) | node_exporter (9100) and, on real hardware with SMART disks, smartctl_exporter (9633), installed with `nix run .#fleet` -> "monitoring apply"; same jobs (`node`, `smartctl`) and alerts as the NixOS hosts, label `class="device"` | `monitoring.node` / `monitoring.smartctl = true` (and `baremetal`, `category`) in `hosts/devices/<name>.nix` |
| Docker containers on devices without NixOS | cAdvisor on the device (port 8080), installed with `nix run .#fleet` -> "monitoring apply" (Ansible) | `monitoring.cadvisor = true` in `hosts/devices/<name>.nix` |
| Podman containers on the monitoring server | cAdvisor on loopback (port 8099) | automatic when the server runs Podman (`cadvisor.nix`) |
| Web pages | HTTP probe: status, response time, certificate expiry | `hosts/websites.nix` |
| Internet connection | ping of 1.1.1.1 and 9.9.9.9 | `modules/servers/monitoring/prometheus.nix` |
| GPUs (altair) | nvidia_gpu_exporter | `hosts/physical/altair/configuration.nix` |
| The monitoring itself | Watchdog to healthchecks.io, scrape and notification failures | `alert-rules.nix`, `alertmanager.nix` |

Exporters listen on all addresses; the firewall of each host lets only the
monitoring server's address reach the exporter ports (9100 node, 9633
smartctl). Of the monitoring stack, Grafana (3000), Prometheus (9090) and
Alertmanager (9093) are reachable on the monitoring server's LAN interface,
without authentication (the LAN is trusted; Phase B adds Caddy with TLS and
a login in front); the exporters on the monitoring server itself (blackbox,
pve, GPU) listen on loopback.

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
| `modules/servers/monitoring/pve.nix` | Proxmox API exporter, its token (sops) and CA |
| `modules/servers/monitoring/cadvisor.nix` | cAdvisor for the server's own Podman containers |
| `scripts/fleet.sh` (`nix run .#fleet`) | task menu; "monitoring apply" installs agents on devices with Ansible |
| `ansible/` | playbooks per agent, pinned collections (`requirements.yml`), `ansible.cfg`; used only through `nix run .#fleet` |
| `modules/servers/monitoring/grafana.nix` | Grafana, data sources, dashboards, image renderer |
| `modules/servers/monitoring/dashboards/*.nix` | the repository's own dashboards (Fleet overview), as Nix data |
| `modules/servers/monitoring/nvidia-exporter.nix` | GPU metrics (altair only) |

## Where to look

- **Grafana** (`http://altair.home.lan:3000`):
  - Home dashboard **Fleet overview**: a table of every pending or firing
    alert (empty = nothing wrong) and UP/DOWN tiles for hosts, websites
    and exporters. This is the Checkmk-like view and works even when
    e-mail does not. It is defined in
    `modules/servers/monitoring/dashboards/fleet-overview.nix`; edits in
    the UI are not kept.
  - Alerting -> Alert rules: every rule with its state and expression.
  - Alerting -> Silences (choose the "Alertmanager" data source at the
    top): mute alerts during maintenance.
  - Dashboards: Node Exporter Full (per host: choose job `node`, then the
    instance), NVIDIA GPU (job `nvidia`), Prometheus Blackbox, Proxmox via
    Prometheus (choose instance `pve`), Cadvisor exporter (containers; job
    `cadvisor`). The
    Blackbox dashboard is built for HTTP probes: choose a page in
    `target`; for a pinged host only Status and Probe Duration show data,
    the HTTP, SSL and DNS panels stay empty by design.
- **Alertmanager UI** (`http://altair.home.lan:9093`): the target of the
  "View In Alertmanager" link in alert e-mails; current alerts and
  silences, the same as Grafana's Alerting pages.
- **Prometheus UI** (`http://altair.home.lan:9090`): the target of the
  "Source" link in alert e-mails (the rule's expression as a graph);
  Status -> Targets shows every scrape target and its last error.
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
| containers | CadvisorDown (no "container stopped" rule: stopped containers just vanish from cAdvisor) |
| proxmox | PveExporterDown, PveGuestDown (only guests set to start at boot), PveGuestNotBackedUp, PveStorageLow, PveStorageCritical |
| monitoring | Watchdog, MonitoringTargetDown, AlertmanagerNotificationsFailing, PrometheusRuleEvaluationFailures, PrometheusConfigReloadFailed |

CpuBusy12h includes the current GPU utilisation of the same host, and
GpuBusy12h is a separate alert, so a long LLM job shows which part is
loaded.

## Everyday tasks

| Task | Steps |
| ---- | ----- |
| Monitor a new NixOS server or VM | `nix run .#new-host` (class `server` or `virtual`), deploy the host, then deploy the monitoring server (`colmena apply --on altair`) so Prometheus learns the new target |
| Ping a device | add `monitoring.ping = true;` to `hosts/devices/<name>.nix`, deploy the monitoring server |
| Add a device | `nix run .#fleet` -> "device add": asks for name, address, SSH, category, baremetal, ping and agents, writes and stages `hosts/devices/<name>.nix`, validates the inventory and the monitoring server, and prints the next steps (commit; rebuild this workstation for the SSH alias; install the agents; deploy the monitoring server) |
| Monitor an existing device with node_exporter / smartctl | add `monitoring.node = true;` (and `smartctl`, `baremetal`, `category`) to its file, rebuild this workstation if the SSH alias is new, `nix run .#fleet` -> "monitoring apply" (check, then apply), deploy the monitoring server |
| Monitor containers on a Docker host | the device needs `lan.ip` and an SSH alias named like the device (`ssh.<name>`); add `monitoring.cadvisor = true;` to its file, run `nix run .#fleet` -> "monitoring apply" (check first, then apply), deploy the monitoring server. Upgrade cAdvisor: change `cadvisor_version` in `ansible/playbooks/cadvisor.yml`, run the task for all devices |
| Monitor a Proxmox host | create the read-only token (commands at the top of `pve.nix`), put its value in `secrets/altair.yaml` as `pve-exporter-token`, add `monitoring.pve = true;` to the device file, deploy the monitoring server. Check the token on Proxmox with `pveum user token permissions prometheus@pve monitoring` |
| Stop pinging a device | remove the line (or the whole file), deploy the monitoring server |
| Add a web page | add an entry to `hosts/websites.nix`, deploy the monitoring server |
| Change a threshold | edit the `t` set at the top of `alert-rules.nix`, deploy the monitoring server |
| Silence an alert | Grafana -> Alerting -> Silences -> data source "Alertmanager" -> New silence |
| Start a scrub now | `sudo systemctl start btrfs-scrub-mnt-data.service` (or `btrfs-scrub--.service` for `/`; `systemctl list-units 'btrfs-scrub-*'` lists them), then `sudo systemctl start btrfs-scrub-metrics.service` |
| Export a result through the textfile collector | write `<name>.prom` (Prometheus text format) to `/var/lib/node-exporter-textfile/`: write a temporary file in the same directory, `chmod 0644`, then `mv` it over the old one, so node_exporter never reads half a file. Example: `btrfs-scrub.nix` |

## Exporting images and data

- **Image of a panel or dashboard**: Share -> Export as image (rendered
  by the image renderer service on the monitoring server).
- **Data behind a panel** (better for analysis than an image): panel
  menu -> Inspect -> Data -> Download CSV, or Inspect -> Panel JSON /
  Query for the exact query.
- **A whole dashboard's definition**: Share -> Export -> JSON.

## Removing old series

Series keep their labels for the whole retention (90 days). When jobs or
labels are renamed, the old names stay in Grafana's drop-downs with empty
graphs until they age out. To delete them earlier, Prometheus' admin API
has to be on for a moment; it stays off normally, because anything that
can reach port 9090 on altair (every device in the LAN, and the Podman
containers on the host network) could then delete data.

1. In `modules/servers/monitoring/prometheus.nix`, inside
   `services.prometheus`, add `extraFlags = ["--web.enable-admin-api"];`
   and activate without making it permanent:
   `colmena apply test --on altair`.
2. On altair, delete by label matcher and free the space:
   ```sh
   curl -s -X POST -g 'http://127.0.0.1:9090/api/v1/admin/tsdb/delete_series' \
     --data-urlencode 'match[]={job="old-job-name"}'
   curl -s -X POST 'http://127.0.0.1:9090/api/v1/admin/tsdb/clean_tombstones'
   ```
3. Remove the flag again and `colmena apply --on altair`.

Deleted series cannot be restored; their history is gone.

## Alert e-mail

Alertmanager hands mail to a send-only Postfix on the monitoring server
(`mail.nix`), which delivers straight to the recipient's mail server. While
the internet is down Postfix queues mail and retries.

Test the path without waiting for an alert:

```sh
# On the monitoring server: Postfix alone
printf 'Subject: postfix test\n\ntest from altair\n' | sendmail -f alertmanager@altair.home.lan marcin@waltharius.pl
mailq                      # empty once delivered
journalctl -u postfix -n 50   # 'status=sent' or the reason for a rejection

# Through Alertmanager: a test alert that resolves after 5 minutes
nix shell nixpkgs#prometheus-alertmanager -c amtool --alertmanager.url=http://127.0.0.1:9093 \
  alert add TestAlert severity=warning host=altair --annotation='summary="Test alert, ignore"'
```

If the receiving server rejects or spam-files the mail (a home address has
no SPF record and no matching reverse DNS), relay through an authenticated
mailbox instead (BACKLOG.md, "Alert mail relay"). Known case: Proton Pass
aliases (SimpleLogin, `passmail.net`) reject the sender
`alertmanager@altair.home.lan` because `home.lan` is not a public domain;
`mailq` then lists the messages with "Sender address rejected: Domain not
found". Messages stuck that way are retried for days: delete them with
`sudo postsuper -d ALL` after fixing the cause.

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
