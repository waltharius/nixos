# Changelog

All notable changes to this repository are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The repository has no releases, so entries are grouped by date and refactor
stage instead of version numbers. Every entry ends with **Lessons learned**:
what went wrong, what was surprising, and what should be done differently
next time. Changes that were reverted stay in the log together with the
reason for reverting them.

## [2026-10-03] Refactor stage 5b step 2 - container metrics, `nix run .#fleet`

Containers on the Docker hosts (VM `docker`, walthpi16) and the Podman
containers on altair are measured by cAdvisor; the agent on devices
without NixOS is installed by the first task of the new `fleet` command.

### Added

- `nix run .#fleet` (`scripts/fleet.sh`, `parts/fleet.nix`): one entry
  point for repository and fleet tasks (stage 8, started here). Without
  arguments it shows a searchable list of tasks (gum); tasks also run
  directly (`nix run .#fleet -- monitoring apply --check --all`). Tasks:
  "monitoring apply" (new) and shortcuts to `new-host`, `install-host` and
  `sops-config`.
- Task "monitoring apply": picks an agent (now only cAdvisor) and the
  devices that request it (`monitoring.<agent> = true`), check or apply,
  then runs Ansible: inventory generated from `nix eval --json .#inventory`
  (hosts named like their SSH aliases, so `~/.ssh/config.d/devices`
  supplies address, user and key; root logins become root with su, other
  users with sudo), collections installed from `ansible/requirements.yml`
  into the git-ignored `ansible/.collections` when that file changes.
  After apply it checks that each agent answers on `/metrics`. Ansible is
  a runtime input of the script only (flake.lock), installed in no group.
- `ansible/`: `ansible.cfg`, `requirements.yml` (prometheus.prometheus
  0.30.1, community.general 13.4.0), `playbooks/cadvisor.yml` (role
  prometheus.prometheus.cadvisor: cAdvisor 0.60.3 binary as systemd
  service, 0.0.0.0:8080, `docker_only`).
- Device field `monitoring.cadvisor` (validated: needs `lan.ip` and an SSH
  alias named like the device), set on `docker` and `walthpi16`; target
  list `fleet.monitoring.targets.cadvisor`.
- `modules/servers/monitoring/cadvisor.nix`: cAdvisor (nixpkgs module,
  0.56.2) on the monitoring server when it runs Podman, 127.0.0.1:8099
  (8080 is SearXNG), `-docker_only=true`, reading rootful Podman through
  `/run/podman/podman.sock`. Chosen over prometheus-podman-exporter (no
  NixOS module, different metrics): one exporter for Docker and Podman.
- Prometheus job `cadvisor` (every 30 s): Docker hosts and the local
  cAdvisor, label `runtime` = `docker` / `podman`.
- Alert group `containers`: CadvisorDown.
- Grafana dashboard "Cadvisor exporter" (grafana.com 14282).

### Changed

- open-webui, searxng and zotero2readwise: `autoRemoveOnStop = false`.
  cAdvisor 0.56.2 found no Podman container ('open
  /var/lib/containers/storage/overlay-containers/containers.json: no such
  file or directory'): `podman run --rm`, the oci-containers default,
  stores containers in `volatile-containers.json`, which cAdvisor reads
  only from 0.60 on. The oci-containers unit removes the container in
  postStop and before every start, so dropping `--rm` changes nothing
  else. `cadvisor.nix` warns at evaluation about Podman containers that
  still use `--rm` while nixpkgs' cAdvisor is older than 0.60.
- searxng.nix and zotero2readwise.nix reformatted with alejandra in a
  separate commit (the pre-commit hook would have done it with the change).
- `nix run .#fleet`: `ANSIBLE_COLLECTIONS_PATH` is set before the
  collections are installed (ansible-galaxy warned that the target was not
  a configured collections path).
- Job `cadvisor` drops series whose `id` ends in "/": Podman runs each
  container in a child cgroup `libpod-<id>.scope/container`, which
  cAdvisor reported next to the scope, so every Podman container appeared
  twice. Under cgroup v2 the scope's statistics include the child.
- Grafana: community dashboards without an automatic refresh get 1m
  (jq in `grafana-provision-dashboards`); the fleet overview keeps 30s.

### Verification

To be run after the deploy; record the results here (and remove this
note):

- `nix run .#fleet` shows the task list; "monitoring apply" in check mode
  on both devices, then apply; both answer on `http://<ip>:8080/metrics`.
- Run on 2026-10-03: "monitoring apply" (check, then apply) on docker and
  walthpi16; both answer on `/metrics`; dashboard Cadvisor exporter lists
  portainer_agent and atuin-server (docker), portainer, gitlab and
  vikunja-todo-vikunja-1 (walthpi16).
- altair, run on 2026-10-03 after the `autoRemoveOnStop` change: no new
  'Failed to create existing container' errors; cAdvisor reports
  open-webui and searxng and no systemd services (`-docker_only` keeps the
  Podman containers), each twice (scope and `/container` child; the
  child is now dropped). Still to check after this deploy: one row per
  container in the dashboard.
- Prometheus target `cadvisor` up for docker, walthpi16 and altair;
  dashboard Cadvisor exporter shows containers per host.

### Lessons learned

- A tool's support for a runtime is only as good as its version: the
  Podman handler of cAdvisor 0.56 assumed a storage layout (one
  `containers.json`) that Podman no longer guarantees. The error message
  named the missing file; reading the handler's code for that path found
  the cause faster than guessing.

## [2026-10-02] Atuin login from sops on workstations, key check on every host

Workstations logged in to Atuin by hand. A host that ran Atuin before
logging in with the fleet key synced records nobody else could decrypt:
sukkub (repaired 2026-09-30), and on 2026-10-02 again records under a third
key from a host whose store was created on 2026-10-01 at 08:57 UTC (host
ID `01a0f6ae...`, a UUIDv7 timestamp; baal was installed that day), while
the current key of azazel, baal, altair and cloud-apps matched the fleet
key. Records uploaded under a wrong key stay on the server after the host
switches keys; only the store repair (`store purge`, `push --force`,
`pull --force`) removes them.

### Changed

- `modules/servers/atuin-login.nix` moved to `modules/system/atuin-login.nix`
  and generalised: one oneshot service per account,
  `atuin-auto-login-<user>` (was `atuin-auto-login`, nixadm only). Default
  accounts: those of marcin and nixadm that exist on the host; keeper is
  left out (separate Atuin account in stage 6).
- Every workstation enables it (`lib/classes.nix`), so marcin logs in with
  the fleet key from `secrets/atuin-key.txt`; the generated `.sops.yaml`
  adds the workstations to the Atuin secret files.
- altair: the unexplained `services.atuin-auto-login.enable = lib.mkForce false`
  is removed; nixadm there gets the key check like the other servers.
- The service compares the local key with the fleet key on every start
  and fails with exit code 3 (no retry) when they differ; it never
  re-keys a store. Network failures are retried every minute.
- "Logged in" is detected by Atuin's session file instead of
  `atuin status`, which needs the server.

### Verification

Run on 2026-10-03:

- Store repaired again with the procedure of 2026-09-30 (azazel: store
  purge, history init-store, push --force; altair and cloud-apps:
  pull --force, rebuild history). baal was not logged in again (it already
  had the fleet key); its local store, which still held its first records
  under the old key, verifies after the repair.
- cloud-apps and altair: atuin-auto-login-nixadm reports 'Already logged
  in to Atuin with the fleet key'.

Still to check: azazel and baal (`systemctl status atuin-auto-login-marcin`),
`atuin store verify` on every host.

### Lessons learned

- A shared encryption key that each machine receives by hand drifts as
  soon as one machine is set up differently. Hand it out from the secret
  store, and check it on every start instead of trusting that a login
  once happened correctly.
- Equal keys on every host today do not prove the server's data is clean:
  the check covers the key a host uses now, not records it uploaded
  earlier. `atuin store verify` on a host that has pulled everything is
  the check for the data.

## [2026-10-02] Monitoring: working links in alert e-mails, Grafana root_url

### Changed

- Alertmanager and Prometheus listen on all addresses; ports 9093 and 9090
  are open on altair's LAN interface only (like Grafana's 3000), without
  authentication. Their `webExternalUrl` is
  `http://<host>.<networking.domain>:<port>` (`http://altair.home.lan:9093`,
  `:9090`). Before, the "View In Alertmanager" and "Source" links in alert
  e-mails used the default external URL (`http://altair:9093`) of a
  service listening on loopback only, and the browser timed out.
- Grafana `root_url` set to `http://altair.home.lan:3000/`: absolute links
  built by Grafana (share links, image export) pointed to
  `http://localhost:3000`.
- PveGuestDown and PveGuestNotBackedUp skip templates
  (`pve_guest_info{template="1"}`); PveGuestNotBackedUp also skips guests
  with the Proxmox tag `nobackup`.

### Verification

Run on 2026-10-02: from azazel `http://altair.home.lan:9093` and `:9090`
open, and the "View In Alertmanager" and "Source" links in alert e-mails
work. Not yet checked: Grafana Share -> Export as image (BACKLOG.md).

### Lessons learned

- Alertmanager and Prometheus put their external URL into every
  notification. A service that listens on loopback still needs a
  reachable external URL as soon as anything it sends leaves the host.

## [2026-10-02] Refactor stage 5b step 1 - Proxmox through the pve exporter

First step of stage 5b (BACKLOG.md): Proxmox VE, its guests and storage
are read through the Proxmox API by an exporter on the monitoring server;
nothing is installed on Proxmox.

### Added

- `modules/servers/monitoring/pve.nix`: prometheus-pve-exporter on the
  monitoring server (loopback, port 9221), enabled when a device sets
  `monitoring.pve = true`. Read-only API token `prometheus@pve!monitoring`
  (PVEAuditor on `/`, privilege separation off); its value is
  `pve-exporter-token` in `secrets/altair.yaml`, the environment file is a
  sops template. Exporter defaults kept (including backup-info, which the
  NixOS module has no option for); replication collector off.
- Device field `monitoring.pve` (validated in `lib/inventory.nix`), set on
  `hosts/devices/pve.nix`; target list `fleet.monitoring.targets.pve`.
- Prometheus job `pve` (multi-target, `/pve?target=<lan.ip>&cluster=1&node=1`,
  every 30 s, timeout 20 s), labels `instance` and `host` = `pve`.
- Alert group `proxmox`: PveExporterDown, PveGuestDown (guests set to start
  at boot, not running for 5 minutes), PveGuestNotBackedUp (guest in no
  backup job for an hour), PveStorageLow and PveStorageCritical (same free
  space thresholds as the filesystems). Guest alerts carry the guest name
  joined from `pve_guest_info`.
- Grafana dashboard "Proxmox via Prometheus" (grafana.com 10347).
- Website probe `pve-web` (`https://192.168.50.200:8006/`), so the FreeIPA
  certificate of pveproxy is watched by WebsiteCertificateExpiring.
- `certs/freeipa-ca.crt`: the FreeIPA CA as a file.

### Changed

- `modules/system/certificates.nix` reads the FreeIPA CA from
  `certs/freeipa-ca.crt` instead of an inline string (same string, so the
  system CA bundle of every host should stay the same).
- `prometheus.nix`: the `?target=` relabelling of the blackbox jobs is a
  helper (`viaExporter`) shared with the pve job; the blackbox jobs are
  unchanged.

### Verification

Run on 2026-10-02 after the deploy:

- `curl -s 'http://127.0.0.1:9221/pve?target=192.168.50.200&cluster=1&node=1'`
  on altair lists the node, 9 LXC containers, 2 VMs and 6 storages
  (token and FreeIPA CA verification work). Two guests are stopped and in
  no backup job: `lxc/108` and `lxc/9000`.
- Grafana dashboard Proxmox via Prometheus shows data.

Still to check:

- `nvd diff` on a host other than altair: no change from the
  certificate file.
- Alerting -> Alert rules lists the `proxmox` group;
  PveGuestNotBackedUp for `lxc/108` (and `lxc/9000` if it is not a
  template, see the follow-up entry).
- Blackbox target `pve-web` up, certificate expiry about 2027-09-13.

### Lessons learned

- Python programs from nixpkgs verify TLS against nixpkgs' own CA bundle
  (certifi points at `cacert`), not the system bundle that
  `security.pki` fills. An internal CA has to be passed explicitly, here
  with `REQUESTS_CA_BUNDLE`.
- Proxmox serves `pveproxy-ssl.pem` when it exists; `pve-ssl.pem` (signed
  by the cluster CA, with the old address 192.168.50.109 in its SAN) is
  then not what clients see. Check the certificate the service actually
  presents before deciding how to verify it.
- In PromQL `*` binds tighter than `==` and `and`; joining a label with
  `* on (...) group_left (...)` after a filter needs parentheses, or the
  join silently lands on the wrong operand. Tested with `promtool test
rules` before the commit.

## [2026-10-02] Monitoring: fleet overview dashboard, image export, instance labels

Follow-up to stage 5a after the first days of use.

### Added

- Grafana home dashboard "Fleet overview"
  (`modules/servers/monitoring/dashboards/fleet-overview.nix`, Nix data
  provisioned as JSON): table of pending and firing alerts (Prometheus'
  `ALERTS` series, Watchdog excluded) and UP/DOWN tiles for pinged hosts,
  websites and exporters, website response times, certificate expiry. The
  Checkmk-like overview that also works when e-mail does not.
- Grafana image rendering (`services.grafana-image-renderer`, headless
  Chromium): Share -> Export as image. Grafana and the renderer share a
  token (`grafana-renderer-token` in `secrets/altair.yaml`): Grafana 13
  refuses to start with the default renderer token.
- `docs/MONITORING.md`: exporting images and data, removing old series,
  how to read the Blackbox dashboard.

### Changed

- Alert e-mail recipient: marcin@waltharius.pl instead of the Proton Pass
  alias, which rejects the sender domain `home.lan` (`hosts/fleet.nix`).
- `docs/MONITORING.md`: the amtool test command quotes the annotation
  value (`summary="..."`) for Alertmanager's new matcher parser.
- Local scrape jobs on the monitoring server (`nvidia`, `incus`,
  `prometheus`, `alertmanager`, `blackbox`) set `instance` to the host
  name, like the generated jobs: dashboards show `altair` instead of
  `127.0.0.1:<port>`.

### Fixed

- btrfs scrub ran twice per filesystem and `btrfs-scrub.prom` held every
  series twice: nixpkgs already sets `services.btrfs.autoScrub.fileSystems`
  to one mount point per device with `mkDefault`, and the stage 5a module
  set the same list at the same priority, so the module system
  concatenated them. The module no longer sets `fileSystems`; the metrics
  job deduplicates its arguments.

### Removed

- Series of the jobs renamed in stage 5a (`altair-node`, `altair-nvidia`,
  `opnsense firewall`) and of the old `127.0.0.1:*` instances, deleted
  through the admin API once (procedure in `docs/MONITORING.md`). They
  showed up as empty choices in the dashboards' drop-downs.

### Verification

Run on 2026-10-02:

- First `colmena apply test` failed: Grafana 13 refused the default
  renderer token (fixed with the shared token before the commit).
- Node Exporter Full and NVIDIA GPU list only the jobs `node` and
  `nvidia`, instance `altair`. Not confirmed: whether the old series were
  deleted through the admin API (a series query still returned
  `instance="127.0.0.1:9835"` before the cleanup step).
- Alert e-mail to marcin@waltharius.pl: Postfix test and an amtool test
  alert (FIRING TestAlert) delivered.
- `btrfs-scrub.prom` after the fix: each series once (2 mount points).
- Prometheus: all 27 targets up (node altair and cloud-apps, smartctl,
  nvidia, incus, monitoring stack, 15 ICMP probes, 2 HTTP probes,
  2 internet probes).
- smartctl_exporter sees only `sda`, not the NVMe drive (BACKLOG.md).
- Share -> Export as image fails with "Failed to fetch"; nothing reaches
  the renderer, nothing in Grafana's log (BACKLOG.md).
- Not yet checked: the Fleet overview dashboard itself.

### Lessons learned

- List options merge by concatenation when two modules define them at
  the same priority. Before setting a list option to "the right value",
  check whether nixpkgs already defines it with `mkDefault`.
- Grafana 13 treats the default `[rendering] renderer_token` as a fatal
  error in production mode; enabling the NixOS renderer module alone
  stopped Grafana from starting. A shared token is required.
- Renaming a scrape job or a label leaves the old series for the whole
  retention; plan label names before the first deploy, or budget a
  one-off delete through the admin API.

## [2026-10-02] Refactor stage 5a - monitoring from the inventory, alerting

Goal of this stage: every NixOS server and VM is monitored without naming
it anywhere but in its machine file, alerts reach a person (e-mail, and an
external Watchdog for the case that the monitoring server itself is
down), and Grafana shows every alert. Devices without NixOS get ping now
and full metrics in stage 5b (BACKLOG.md). Overview: `docs/MONITORING.md`.

### Added

- `lib/monitoring.nix`, imported by every host: machines of class
  `server` and `virtual` run node_exporter; class `server` also runs
  smartctl_exporter and a monthly btrfs scrub; the machine named in
  `monitoring.server` (`hosts/fleet.nix`) gets the monitoring stack.
  Scrape targets are generated from the inventory
  (`fleet.monitoring.targets`). Exporter ports are open to the monitoring
  server's address only (nftables or iptables rule, depending on the
  host's firewall backend). Workstations get nothing.
- `hosts/fleet.nix`: `monitoring.server` and `monitoring.mail` (recipient
  and sender of alert e-mails).
- `hosts/websites.nix`: web pages to probe (placeholder entries for now).
- Device field `monitoring.ping`: the device is pinged (HostDown).
- `modules/servers/monitoring/`: `alertmanager.nix` (e-mail of firing and
  resolved alerts, Watchdog webhook to healthchecks.io, HostDown inhibits
  the other alerts of the host), `mail.nix` (send-only Postfix on
  loopback, direct delivery), `blackbox.nix` (ping and HTTP probes),
  `smartctl.nix`, `btrfs-scrub.nix` (scrub once per btrfs device, result
  exported hourly through the textfile collector), `alert-rules.nix`
  (rules as Nix data: availability, websites, resources, services and
  time, hardware, the monitoring itself).
- node_exporter textfile collector (`/var/lib/node-exporter-textfile`) on
  every monitored host.
- Grafana: Alertmanager data source; the Prometheus data source shows the
  Prometheus rules under Alerting -> Alert rules; dashboard "Prometheus
  Blackbox" (grafana.com 15873).
- `docs/MONITORING.md`.

### Changed

- `hosts/devices.nix` split into `hosts/devices/<name>.nix`, one file per
  device, loaded like the machines (`lib/inventory.nix`). Descriptions
  added where the old file only had a section heading.
- Prometheus: jobs generated from the inventory replace the hand-written
  `altair-node`, `altair-nvidia` and `opnsense firewall` jobs. Job names
  are now `node`, `smartctl`, `blackbox-icmp`, `blackbox-http`,
  `blackbox-internet`, `nvidia`, `incus`, `prometheus`, `alertmanager`,
  `blackbox`; series carry `instance` = host name. Old series keep their
  old labels until they age out of the 90-day retention.
- altair: node_exporter listens on all addresses instead of loopback
  (port 9100 open to altair's own address only); the monitoring stack is
  imported through `lib/monitoring.nix`, `nvidia-exporter.nix` directly
  by the host. cloud-apps now runs node_exporter.
- Alert rules generalised from `job="altair-node"` to every host.
- Grafana: new `secret_key`, started with an empty `grafana.db`; the old
  key was the publicly known pre-26.05 default. Dashboard patching
  (`__inputs` removal, datasource UID) now runs on every downloaded
  dashboard, not only the NVIDIA one. Firewall rule uses the host's
  `lan.interface` instead of a hard-coded `enp10s0`.

### Removed

- `hosts/devices.nix` entry `check-mk` (Checkmk is switched off).
- Device `bedroom-asus` (192.168.50.219): only two ASUS routers exist
  (RT-AX92U, gnuton firmware); the entry was left over from the old list.
- Monitoring of OPNsense (broken since an update; the device file stays
  so its address remains reserved).
- Alert GPUMemoryHigh: VRAM above 95 % is the normal state while Ollama
  keeps a large model loaded (BACKLOG.md).
- The commented-out "Phase 4+" monitoring imports in
  `hosts/physical/altair/configuration.nix`.

### Verification

Run on 2026-10-02 after the deploy:

- Deploy of altair and cloud-apps succeeded; Grafana Alerting -> Alert
  rules shows only Watchdog firing.
- healthchecks.io: check green; stopping alertmanager produced its
  e-mail.
- E-mail: rejected by the Proton Pass alias (SimpleLogin: sender domain
  `home.lan` not found); delivered directly to marcin@waltharius.pl. The
  recipient was changed (follow-up entry above).
- btrfs scrub started by hand on `/` and `/mnt/data`; `btrfs_scrub_*`
  series present, no errors. Found: every series written twice (fixed in
  the follow-up entry).
- Metric names: `nvidia_smi_temperature_gpu`,
  `nvidia_smi_utilization_gpu_ratio` (label `uuid` present),
  `smartctl_device_smart_status`, `smartctl_device_temperature` exist.
  `smartctl_device_critical_warning` and `smartctl_device_percentage_used`
  do not: NvmeCriticalWarning and NvmeWearHigh cannot fire yet
  (BACKLOG.md).
- Prometheus targets: all up (checked with the follow-up entry above).

### Lessons learned

- `file_sd` only pays off when something outside the configuration
  changes the targets. With every target in the repository, a deploy is
  needed either way, so generated `static_configs` are the simpler and
  equally reproducible choice.
- Grafana's database holds no metrics: those live in Prometheus. With
  everything in Grafana provisioned, a fresh `grafana.db` (needed to
  change `secret_key`) loses nothing.
- An alerting pipeline cannot report its own death. Before this stage the
  rules existed but had no receiver at all; now an always-firing alert is
  checked from outside (healthchecks.io), which also covers altair
  waiting for its LUKS passphrase after a power cut.

## [2026-10-02] Emacs: Polish Hunspell dictionary converted to UTF-8 at build time

### Fixed

- Spell checking in Emacs could not be enabled: Hunspell printed
  `error - iconv: ISO8859-2 -> UTF-8` after its version line and Emacs
  rejected the process. `hunspell.withDicts` (stage 1) wraps the binary
  with `--prefix DICPATH : <env>/share/hunspell`, so the ISO8859-2
  `pl_PL` from nixpkgs is found before the UTF-8 copy the Emacs
  configuration pointed `DICPATH` at. `modules/groups/emacs/home.nix`
  now converts `hunspellDicts.pl_PL` to UTF-8 in a `runCommand`
  (`hunspellPlUtf8`) and passes it to `withDicts` instead of `pl_PL`.
  The build fails when the source is not declared ISO8859-2 or the
  result is not valid UTF-8.

### Removed

- `home.activation.hunspellUtf8`, which converted the dictionary into
  `~/.local/share/hunspell` at activation. The wrapper never reached
  that copy, and the copy never refreshed: store files have mtime 1, so
  its `-nt` test was false after the first run. Leftover
  `~/.local/share/hunspell/pl_PL.{aff,dic}` are unused and can be
  deleted by hand.
- The unused `lib` argument of `modules/groups/emacs/home.nix`.

### Verification

To be run on azazel; record the results here (and remove this note):

- `nix flake check` passes; `nvd diff` shows only the new dictionary
  derivation and a new `hunspell-with-dicts`.
- `head -c 300 /etc/profiles/per-user/marcin/share/hunspell/pl_PL.aff`
  shows `SET UTF-8`.
- `echo 'błendem colour' | hunspell -a -d pl_PL,en_GB -i UTF-8` prints
  the version line, a suggestion `błędem` and `*`, with no `iconv`
  error.
- In Emacs after a restart: misspellings are underlined while typing,
  and `*Warnings*` has no `my/spelling` entry.

### Lessons learned

- A wrapper that prepends to a search path silently overrides anything
  a client adds to the same variable. Replacing separate packages with
  `withDicts` changed which file Hunspell loads without changing any
  name in the configuration.
- Fixes for a package's data belong in the build, not in an activation
  script writing to the home directory: the latter is invisible to the
  wrapper, outside rollback, and stale after updates.
- The failure was first ruled out by a test on Ubuntu, where the same
  Hunspell 1.7.2 converts ISO8859-2 without errors. A test outside
  NixOS proves nothing about NixOS behaviour; the comment that already
  described the iconv error was the better evidence.

## [2026-10-01] Refactor stage 4 - remote access (Tailscale)

Goal of this stage: reach the home network from away through a Tailscale
subnet router on pfSense, and declare in the inventory which machines run
Tailscale and how they join the tailnet. Servers and virtual machines stay
off the tailnet and are reached through the subnet router.

### Added

- `tailscale` field of `hosts/machines/<host>.nix`: `join` (`owner`,
  `tagged`, `shared`), `acceptRoutes`, `tags`, `operator`; and
  `tailscale.loginServer` in `hosts/fleet.nix` (null: Tailscale's control
  server; later Headscale). `lib/inventory.nix` validates both.
- `lib/tailscale.nix`, a module generated from the inventory and imported
  by every host (like `lib/ssh.nix`). For machines with a `tailscale`
  entry: the client with the firewall port open for direct connections,
  `tailscale0` trusted, client settings re-applied on every boot with
  `tailscale set`, the `tailscale-join` command (`tailscale up` with every
  flag from the repository), the first-boot unit `tailscale-join-once`,
  and for `owner` systemd-resolved (NetworkManager hands DNS to it),
  operator marcin and `tailscale-systray`.
- Home Wi-Fi profiles of hosts with `acceptRoutes` carry the routing rule
  `priority 2500 to 192.168.50.0/24 table 254`, so LAN traffic stays off
  the tunnel at home but still uses it away (`modules/system/wifi.nix`).
- `new-host` asks how a workstation joins the tailnet and writes the
  `tailscale` entry; `install-host` asks for a one-off auth key (required
  for `tagged`, optional for `owner`) and leaves it in
  `/var/lib/tailscale-join/auth-key` of the new system, sent over SSH
  stdin.
- `docs/REMOTE-ACCESS.md`: pfSense as subnet router, a draft tailnet
  policy, split DNS for `home.lan`, client behaviour, troubleshooting.
- azazel, sukkub and baal: `join = "owner"`, `acceptRoutes = true`.
- pfSense as the subnet router for `192.168.50.0/24` (Tailscale package,
  tag `tag:router`, pass rule on the Tailscale interface group), set up by
  hand and described in `docs/REMOTE-ACCESS.md`.
- Tailnet policy in `grants` syntax with tests, edited in the JSON editor
  of the admin console (copy in `docs/REMOTE-ACCESS.md`); split DNS
  `home.lan` -> 192.168.50.1 and the search domain `home.lan`.
- Declarative profile `hotspot-kontestator` for the phone hotspot in
  `modules/system/wifi.nix`: lowest autoconnect priority, IPv6 off, DNS
  9.9.9.9 and 1.1.1.1 (password `HOTSPOT_KONTESTATOR` in
  `secrets/wifi.env`).

### Changed

- azazel: Tailscale is configured by the repository and stays connected,
  instead of `tailscale up --accept-routes` by hand when needed.
- `owner` workstations resolve names through systemd-resolved instead of
  a `/etc/resolv.conf` written by NetworkManager.
- Tailnet: Tailscale's default allow-all policy replaced; only
  `group:admin` (marcin's devices) may start connections, tagged devices
  only answer.

### Removed

- `modules/services/tailscale.nix` (azazel only), replaced by
  `lib/tailscale.nix`.
- The commented-out imports of the non-existent
  `modules/servers/network/tailscale.nix` and `yggdrasil.nix` in altair's
  configuration.

### Verification

Run on azazel on 2026-10-01:

- Away from home (phone hotspot): `ip route get 192.168.50.150` shows
  `tailscale0`, `ping` and `ssh altair` work, `resolvectl query
altair.home.lan` answers through `tailscale0`. The connection to pfSense
  is relayed through DERP (Warsaw), never direct (`tailscale ping
pfsense`): about 100-200 ms.
- At home: `ip rule` shows the rule with priority 2500 (only while a home
  profile is up).
- Tailnet policy tests pass on save.
- Browsing on the hotspot failed until the hotspot profile got IPv6 off
  and public DNS (see Added, Lessons learned).

Still to check, with the rebuild of sukkub and baal:

- `tailscaled-set` succeeds on a host that is not yet logged in;
  `tailscale-join` logs it in.
- altair and cloud-apps: system derivations equal to the commit before
  the stage (they only gain the option `fleet.tailscale.lanRoutingRule`).

### Lessons learned

- On Linux, a client that accepts subnet routes sends traffic for its own
  LAN through the subnet router when the router advertises that LAN:
  Tailscale's policy routing rules (5200-5500) win over the normal route.
  The documented bypass rule is meant for fixed networks; tying it to the
  home Wi-Fi profiles keeps it from applying on foreign networks.
- Without a DNS manager Tailscale rewrites `/etc/resolv.conf` and fights
  whatever else writes it; with systemd-resolved it adds its DNS per
  interface.
- A subnet router on a server would make remote access depend on two
  machines; on the router it depends on one that the network needs
  anyway.
- An untagged device that publishes a service with Funnel counts as one of
  marcin's devices in the tailnet policy and can start connections to the
  whole LAN through the subnet router. Tag such devices.
- Headscale cannot run behind Cloudflare Proxy or Tunnel and has no
  Funnel; moving to it needs a public address and calibre off Funnel first.
- systemd-resolved is less forgiving than a plain `/etc/resolv.conf`:
  with a phone hotspot's DNS proxy and unreachable IPv6 DNS servers it
  timed out, while baal (still without resolved) worked on the same network.
  Test a resolver change on the networks actually used.
- pfSense drops traffic from the tailnet until the Tailscale interface
  group has a pass rule. Split DNS for `home.lan` worked before that rule
  existed, so a working DNS lookup does not prove the LAN is reachable:
  test with ping or SSH to a LAN host.
- Android accepts subnet routes by default: the phone reaches the home
  LAN through the subnet route, no exit node needed. An exit node sends
  all internet traffic through home (and here through the relay).
- After `tailscale down`, bring the client back with `tailscale-join`, not
  a bare `tailscale up`, which refuses to change settings unless every
  non-default flag is repeated.
- Rewriting commits that are already pushed (`git rebase HEAD~N` over
  `origin/main`) or editing on one of two remotes makes the histories of
  GitLab and GitHub diverge; only rewrite commits after `@{upstream}`.

## [2026-10-01] Refactor stage 3 - installing hosts (baal)

### Added

- `nix run .#install-host -- <host> root@<address>`
  (`scripts/install-host.sh`): installs a host registered with `new-host`
  using nixos-anywhere, with the stored SSH host key, the LUKS passphrase
  handed to the installer and `hardware-configuration.nix` generated on
  the target.
- `install-host` asks for an initial password of every account and sets
  its yescrypt hash before the first boot (nixos-anywhere runs without
  its reboot phase). baal was installed before this and came up with
  locked accounts.
- marcin's `openssh.authorizedKeys`: the LAN admin key, on every host with
  marcin (fresh hosts had no way in over SSH).
- Disk layout `btrfs-luks-writing` and host template `writing.nix`:
  marcin's writing subvolumes with snapshots, as on azazel.

### Changed

- The `btrfs-luks` layouts read the passphrase from `/tmp/secret.key`
  while formatting (nixos-anywhere `--disk-encryption-keys`).
- `new-host` offers every layout in `hosts/templates/disko/` and formats
  the files it writes.
- Group `notes` removed: Obsidian moved to `office`, Hugo to `web` (the
  note-taking tool is Emacs).
- `video=efifb:3840x2160` moved from `modules/system/boot.nix` (every
  workstation) to azazel, whose panel it describes.
- Group `syncthing` replaces the identical `services.syncthing` blocks in
  azazel's and sukkub's configuration.nix; Syncthing runs as the account
  that has the group (baal gets it by adding the group).

- baal hibernates into its swap file after 4 hours of suspend
  (`hosts/workstations/baal/hibernate.nix`).
- The GitLab host key on walthpi16 is pinned under
  `[gitlab.home.lan]:2424`, the name the repositories use.

### Fixed

- `buku-auto-export` ran `~/.nix-profile/bin/buku-export`, which does not
  exist when Home Manager installs into `/etc/profiles/per-user/<user>`.

### Verification

- baal (Dell Wyse 5470) installed with `install-host`: LUKS, btrfs
  subvolumes incl. the writing subvolumes with snapper configs and ACLs,
  8 GiB swap file, SSH host key from the repository (sops decrypted
  during the install), static .82 on the home Wi-Fi, GitHub with the
  pinned host key, SSH from azazel, Atuin, suspend and resume.
- `nixos-rebuild --target-host marcin@baal` from azazel after the
  trusted-users change.
- Hibernation (`resume_offset` 533760): to be tested with
  `systemctl hibernate`.
- gitlab.com rejects the gitlab key: the key is not registered on the
  account (not a configuration problem).

## [2026-09-30] Refactor stage 2 - generated sops audiences, new-host, fleet SSH

Goal of this stage: add a machine in one step (`nix run .#new-host`), let
the configuration decide who can decrypt which secret, and describe SSH
access to the whole network in the repository. Existing hosts keep their
age keys; only new hosts derive theirs from the SSH host key.

### Added

- `hosts/machines/<host>.nix`: one inventory file per machine, loaded
  automatically; fleet-wide settings in `hosts/fleet.nix`.
- Generated `.sops.yaml` (`lib/secrets.nix`, `parts/secrets.nix`). The
  audience of a secret file is: the admin keys, every host whose
  configuration uses the file as `sopsFile`, and hosts listing it in
  `sops.extraSecrets`. Anything else below `secrets/` is admin-only.
  `nix run .#sops-config` writes the file and runs `sops updatekeys`.
- Checks: `sops-config` (committed `.sops.yaml` is up to date) and
  `sops-recipients` (every encrypted file has exactly the recipients its
  rule names, read from the sops metadata).
- `sops.ageKey` / `sops.keySource` per machine, `sops.admins` in
  `hosts/fleet.nix`; inventory validation of both.
- `nix run .#new-host` (`scripts/new-host.sh`, `docs/NEW-HOST.md`):
  inventory entry, host files from `hosts/templates/`, disko layout
  (`btrfs`, `btrfs-luks`), placeholder hardware configuration, new SSH host
  key stored encrypted for the admin keys in `secrets/hosts/<host>/`, age
  key derived from it, `.sops.yaml` regenerated, host evaluated.
- `hosts/devices.nix`: non-NixOS devices (routers, Proxmox and its guests,
  Raspberry Pis, other computers). Their addresses are validated together
  with the machines'; their SSH aliases are generated.
- Layered SSH host lists in `~/.ssh/config.d/` for marcin: `local` (never
  managed), `hosts` (encrypted), `fleet` (from `hosts/machines/`),
  `devices` (from `hosts/devices.nix`), with a README in the directory and
  `docs/SSH.md`.
- `/etc/ssh/ssh_known_hosts` on every host from the inventory
  (`ssh.hostKey`, device `hostKey`) plus the published ed25519 keys of
  github.com and gitlab.com (`lib/ssh.nix`).
- Check `colmena-hive` now fails when a Colmena node and its
  `nixosConfigurations` entry have different system derivations.

### Changed

- Colmena nodes get the flake metadata `lib.nixosSystem` adds
  (`system.nixos.versionSuffix`, `system.nixos.revision`,
  `nixpkgs.flake.source`). Servers deployed with Colmena now carry the same
  system label as with `nixos-rebuild` (`26.05.<date>.<rev>` instead of
  `26.05pre-git`) and a nixpkgs flake registry entry.
- marcin's SSH keys are decrypted by the system sops-nix with the host key
  (`users/marcin/secrets.nix`) instead of Home Manager with a user key.
  `secrets/ssh.yaml` is split into `secrets/users/marcin/git.yaml`
  (GitHub/GitLab keys; hosts where marcin has `emacs` or `nix-admin`) and
  `secrets/users/marcin/admin.yaml` (LAN admin key and private host list;
  `nix-admin` only).
- `modules/system/secrets.nix` uses `/var/lib/sops-nix/key.txt` only on
  `key-file` hosts; `ssh-host-key` hosts use the SSH host key alone.
- `modules/servers/base-baremetal.nix` takes the static address and the
  interface from the inventory (`lan.ip`, new field `lan.interface`)
  instead of altair's hard-coded values.
- Secret audiences: sukkub no longer decrypts the Atuin, Nextcloud and
  MariaDB secrets (nothing on sukkub uses them).

### Removed

- The hand-written `.sops.yaml` with rules for files that did not exist
  (`common.yaml`, `sukkub.yaml`, `azazel.yaml`).
- `hosts/inventory.nix`, `secrets/ssh.yaml`, the Home Manager sops setup of
  marcin.

### Verification

To be run on azazel after applying the series; record the results
here (and remove this note):

- `nix flake check` passes (inventory, colmena-hive parity, sops-config,
  sops-recipients).
- Commit 1 (inventory split): system derivations of all four hosts equal
  to the previous commit.
- Afterwards, expected differences only: known_hosts on every host;
  system label and flake registry on altair and cloud-apps (Colmena);
  marcin's key delivery and `~/.ssh/config.d/` on azazel and sukkub.

### Lessons learned

- sops encrypts a whole file for all its recipients. A host that needs one
  value of a file can read all of them; secrets with different audiences
  need different files (`ssh.yaml` held both git keys and the LAN admin
  key).
- sops-nix creates missing parent directories of a secret's `path` as
  root. A secret placed in `~/.ssh` on a fresh host would leave `~/.ssh`
  owned by root; the directory has to exist before `setupSecrets` runs.
- The hand-written `.sops.yaml` had already drifted: its rule for
  `ssh.yaml` named altair, the file was not encrypted for altair. Comparing
  the rule with the recipients actually stored in the file catches this;
  comparing the rules alone does not.
- Home Manager renders the `Host *` block last in `~/.ssh/config`, so
  host-specific blocks written there take precedence over anything
  included from `Host *`.
- `base-baremetal.nix` looked generic but contained altair's address and
  interface; a second server would have taken altair's IP.
- Evaluation of the whole fleet does not fit into a small sandbox; the
  equality and drift checks are meant to run on the admin workstation.

## [2026-09-30] Refactor stage 1 - groups, accounts and a shared shell

Goal of this stage: describe what a host runs as groups chosen per user in
`hosts/inventory.nix`, define accounts in one place, and give every admin
account the same shell on every host. Unlike stage 0 the system derivations
change; the check is that no program disappears (see "Verification").

### Added

- Program groups (`modules/groups/`): `gnome`, `emacs`, `office`, `latex`,
  `notes`, `web`, `comms`, `media`, `gaming`, `nix-admin`, `cli`. Each group
  has a system part (`nixos.nix`), a user part (`home.nix`) or both, and is
  registered in `modules/groups/default.nix`.
- `machines.<host>.users.<user>.groups` in `hosts/inventory.nix`. A host
  gets the system part of every group of every user; each user gets the
  user part of their own groups (`lib/users.nix`).
- Account definitions in one place: `users/<user>/account.nix`. The
  inventory decides on which hosts an account exists.
- Admin base (`modules/home/admin/`) for marcin, nixadm and the future
  keeper on every host: nixvim, bash, ble.sh, starship, zoxide, atuin, eza,
  git.
- Inventory validation: unknown group, account without
  `users/<user>/account.nix`, machine without users, server or virtual
  machine without nixadm.
- Flatpak apps declared in groups (nix-flatpak, user installation):
  Quick PDF Join (`office`), JDownloader (`web`), Fedora Media Writer
  (`nix-admin`). Unmanaged apps are left alone.
- `host` module argument (inventory entry plus name) for NixOS and Home
  Manager modules, e.g. `host.class`.
- Every workstation now gets audio, printing, Flatpak, certificates,
  Plymouth, the sudo policy and Nerd Fonts from its class
  (`lib/classes.nix`, `modules/system/fonts.nix`) instead of a per-host list.

### Changed

- `hosts/workstations/<host>/profile.nix` renamed to `custom.nix`; it holds
  only hardware and host features. `users/marcin/profiles/` is gone.
- marcin's configuration is split into groups and personal settings
  (`users/marcin/home/`). Personal GNOME settings (extensions,
  run-or-raise, `ctrl:nocaps`) apply only where marcin has `gnome`;
  autostart entries only where the program is installed.
- Shell start-up: ble.sh is sourced detached after the interactive-shell
  guard and attached last; starship, atuin and zoxide are initialised once,
  by their Home Manager modules. Before, starship ran in `bashrcExtra` (also
  in non-interactive shells) and all three were initialised twice.
- One Atuin module for all admin accounts (`modules/home/admin/atuin.nix`);
  the daemon on workstations is Home Manager's socket-activated service.
- nixadm has the same shell as marcin: `gst` instead of `gs` (Ghostscript's
  name), zoxide replaces `cd`, starship shows the host name in red outside
  workstations, plus nixvim and the `cli` group on servers.
- `btrfs-writing-monitor` and the `bwm` alias come with
  `modules/system/btrfs.nix` instead of marcin's packages.
- nixvim's nixd completion for Home Manager options uses the current user
  instead of a hard-coded marcin.

### Fixed

- Atuin credentials no longer appear on command lines (readable by every
  user in `/proc/<pid>/cmdline`). The server login service
  (`modules/servers/atuin-login.nix`) passed the password and key inside
  `expect -c "..."`; the expect script now reads the credential files
  itself. The Home Manager login service, which passed the key with
  `atuin login -k`, is removed.
- yazi on servers no longer pulls ffmpeg, ImageMagick, poppler, resvg and
  chafa. The first stage 1 deploy to cloud-apps still copied them: nixpkgs'
  `yazi` wrapper adds these preview helpers itself (`optionalDeps`), so
  leaving them out of `home.packages` was not enough.

### Removed

- Modules that no host imported, and their documentation: Doom Emacs
  (`modules/home/utils/doom-emacs/`), niri (`modules/system/niri.nix`,
  `modules/home/desktop/niri.nix`, `docs/niri.md`), the plain Neovim
  configuration with its org-mode add-on (`modules/utils/neovim.nix`,
  `neovim-org.nix`, `lua/org-mode-denote.lua`, `nixvim/org-mode.nix`,
  `docs/README.md`, `docs/neovim-org.md`, `docs/SETUP-ORG-MODULE.md`),
  `modules/system/grub.nix`, two unused Thunderbolt fixes
  (`thunderbolt-coldboot-fix.nix`, `thunderbolt-hibernate-fix.nix`), the Home
  Manager Syncthing module (`modules/services/syncthing.nix`), Bottles for
  Scrivener (`modules/home/tools/writing.nix`) and `modules/home/tools/hugo.nix`.
  Removing them left the system derivation of every host unchanged.
- Host `actual-budget` and its role module, and the unused LXC template
  `hosts/virtual/base-template/`.
- Unused programs: silverbullet, nb, alacritty, the system-wide neovim
  (admin accounts use nixvim), TeX Live medium on sukkub (marcin has the
  full scheme through `latex`).
- Duplicates: Brave, git, yazi, starship, zoxide, atuin, solaar and ptyxis
  were installed both by a module and by a package list. blesh is no longer
  in marcin's profile either: `.bashrc` sources ble.sh by its store path.
- The `pnpm-10.29.2` insecure-package exception on azazel: signal-desktop
  now builds with pnpm 11.27.0, which has no known vulnerabilities.
- The `y` shell function in bash; yazi's Home Manager wrapper defines it.

### Verification

Before and after, for azazel, sukkub, altair and cloud-apps: the lists of
system packages, Home Manager packages, Flatpak apps, system services,
user services, managed home files and dconf settings (Nix 2.18, same
`flake.lock`). All differences are listed here:

- azazel, sukkub: removed only the programs listed above under "Removed";
  Nerd Fonts moved from marcin's packages to `fonts.packages`; three Flatpak
  apps are now declared; the Atuin daemon gained its socket unit;
  `btrfs-writing-monitor` moved from marcin's packages to the system on
  azazel, and sukkub loses it (it has no writing subvolumes to monitor).
  System services and dconf settings unchanged.
- altair, cloud-apps: nixadm gains nixvim, eza, git and the `cli` group
  (yazi without preview helpers, tmux with marcin's configuration); the
  broken Home Manager `atuin-login` user service is gone. System services
  unchanged.
- All four hosts evaluate both as `nixosConfigurations` and as Colmena
  hive nodes. The inventory validation was checked with a deliberately
  broken copy: an unknown group, an account without `account.nix` and a
  server without nixadm were all reported.

### Lessons learned

- Comparing package, service and file lists per host catches what a
  derivation hash cannot explain once a change is meant to alter systems:
  every difference has to be either intended or explained.
- A comment in `packages.nix` claimed that packages installed by Home
  Manager program modules were not listed again; five of them were (git,
  yazi, atuin, starship, zoxide). Program modules already put their
  package in the profile.
- Home Manager orders `.bashrc` with `lib.mkOrder` inside `initExtra`
  (bash-completion 100, starship 1900, zoxide 2000). ble.sh has no Home
  Manager module, so its source/attach lines need explicit orders around
  those.
- A secret passed to `expect -c "..."` is as visible as one passed to the
  program itself: the whole script is an argument of expect.
- Comparing package lists misses dependencies hidden inside a wrapper
  (yazi's preview helpers). `nvd diff` or the list of paths copied by
  `colmena apply` shows them; read it before calling a change verified.

## [2026-09-30] Refactor stage 0 - flake-parts skeleton and host inventory

Goal of this stage: restructure the flake without changing any deployed
system. Every host must evaluate to exactly the same system derivation as
before (see "Verification" below).

### Added

- `flake.nix` rebuilt on [flake-parts](https://flake.parts); all outputs are
  defined by modules in `parts/`:
  - `parts/hosts.nix` - `nixosConfigurations`, `colmenaHive`, `inventory`
    and the checks `inventory` and `colmena-hive`.
  - `parts/packages.nix` - custom packages from `packages/`.
  - `parts/dev.nix` - `nix develop` shell (colmena, sops, age, ssh-to-age),
    `nix fmt` (alejandra) and git pre-commit hooks (alejandra only).
- `hosts/inventory.nix` - single source of truth for every machine: class,
  system, description, tags, static LAN address and deployment overrides.
  Its shape mirrors Clan's inventory to keep a later migration mechanical.
- `lib/inventory.nix` - inventory validation, enforced on every evaluation:
  known class, `system` present, static `lan.ip` for `server` and `virtual`
  machines, addresses inside `192.168.50.0/24` and outside the router's DHCP
  pool (`.165`-`.199`), no duplicate addresses.
- `lib/classes.nix` - host classes `workstation`, `server` and `virtual`,
  each defining the module list, `specialArgs` and Colmena defaults.
- `lib/default.nix` - builds `nixosConfigurations` and the Colmena hive from
  the same per-host module list, so nothing about a host is defined twice.
- `nixosConfigurations.cloud-apps` - servers and virtual machines can now be
  rebuilt locally with `nixos-rebuild --flake .#<host>` when Colmena is not
  available.
- Workstations are part of the Colmena hive with local-only deployment
  (`colmena apply-local --sudo`).
- Flake output `inventory` (`nix eval --json .#inventory`) for external
  tooling such as the private documentation.
- Colmena `meta.allowApplyAll = false`: a bare `colmena apply` is refused;
  nodes must be selected with `--on <host>` or `--on @<tag>`.
- `BACKLOG.md` - work deliberately postponed until after the refactor.
- `.gitignore`: `.pre-commit-config.yaml` (generated symlink).

### Changed

- Colmena upgraded from 0.4.0 (nixpkgs) to 0.5.0 (flake input pinned to the
  `v0.5.0` tag). The hive is exposed as `colmenaHive`
  (`colmena.lib.makeHive`); the legacy `colmena` output is gone.
- marcin's home packages install Colmena from the flake input instead of
  nixpkgs, so the CLI always matches the hive format in `flake.lock`.

### Removed

- `colmena.nix` and the `mkHost` / `mkVirtual` / `mkPhysicalServer`
  functions in `flake.nix` - replaced by `lib/`. The module lists had been
  duplicated between `flake.nix` and `colmena.nix`.
- Host `nixos-test` (the container no longer exists).
- `REFACTOR.md` - planning notes that were only partly implemented;
  superseded by this changelog.
- `README.org` - duplicate of `README.md`.

### Verification

System derivations evaluated before and after the change (Nix 2.18,
same `flake.lock` for all pre-existing inputs):

| Host       | Output                | Before = after                            |
| ---------- | --------------------- | ----------------------------------------- |
| azazel     | `nixosConfigurations` | yes                                       |
| sukkub     | `nixosConfigurations` | yes                                       |
| altair     | `nixosConfigurations` | yes                                       |
| altair     | Colmena hive          | yes (0.4.0 evaluator vs 0.5.0 `makeHive`) |
| cloud-apps | Colmena hive          | yes (0.4.0 evaluator vs 0.5.0 `makeHive`) |
| cloud-apps | `nixosConfigurations` | new output, no baseline                   |

The only intended system change is Colmena 0.5.0 in marcin's packages on
the workstations (separate commit).

### Lessons learned

- A structural refactor can be proven harmless by comparing
  `config.system.build.toplevel.drvPath` before and after. Identical
  derivation paths mean identical systems, independent of how the Nix code
  is organised.
- Module order matters: list-typed options such as
  `environment.systemPackages` merge in module order. The module lists in
  `lib/classes.nix` keep the old order on purpose.
- `nixos-rebuild --flake` and Colmena build different system derivations for
  the same host. `lib.nixosSystem` adds flake metadata (version suffix with
  the nixpkgs revision, `nixpkgs.flake.source`); Colmena's evaluator calls
  `eval-config.nix` directly and does not. The system label shows it:
  `26.05.20260920.6d663c0` vs `26.05pre-git`. Left unchanged in this stage.
- Colmena 0.4's flake support uses a legacy evaluator that is deprecated and
  does not work in pure mode on Nix 2.21+. 0.5 reads `colmenaHive` instead,
  which also makes the CLI and hive versions a single pinned input.
- `nix develop --option extra-substituters ...` has no effect for marcin:
  marcin is not a trusted Nix user, so client-side substituters and keys are
  ignored. Colmena 0.5.0 was compiled from source on the first run.
