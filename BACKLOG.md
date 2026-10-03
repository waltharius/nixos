# Backlog

Work that was deliberately postponed while refactoring the repository.
Each item says why it waits and what has to be decided first. When an item
is done, move it to `CHANGELOG.md` together with its lessons learned.

## Refactor stages still ahead

5b. Monitoring of Proxmox, containers and devices without NixOS (stage
<<<<<<< ours
5a covered the NixOS machines, ping of devices, websites and alerting;
docs/MONITORING.md). Decided on 2026-10-02, in this order (the user's
priority is Proxmox and containers):

1.  ~~Proxmox: prometheus-pve-exporter on altair~~: done on 2026-10-02
    (CHANGELOG.md).
2.  **Containers**: cAdvisor on the Docker VM (`docker`: portainer
    agent, atuin-server) and on walthpi16 (`docker ps` on 2026-10-02:
    gitlab-ce, vikunja, portainer), prometheus-podman-exporter on altair
    (Open WebUI, SearXNG, zotero2readwise), Incus is already scraped.
    Labels `host` and `runtime` (docker, podman, incus, lxc, vm); a
    "Containers" dashboard: choose a host, see every container.
3.  **node_exporter on everything with Linux** (pve, Proxmox guests on
    Debian/Ubuntu/Alpine/Rocky, walthpi, walthpi16), smartctl_exporter
    on the bare-metal ones. Onboarding: `nix run .#monitor-device`, a
    `gum` script that asks for the device, writes
    `hosts/devices/<name>.nix` and runs Ansible underneath (the user
    never runs Ansible by hand). Ansible is a runtime input of the
    script only (pinned by flake.lock, not installed in any group); the
    `prometheus.prometheus` collection is pinned in `requirements.yml`
    and installed into a git-ignored directory in the repository. The
    script has an "apply to all devices" mode for version or setting
    changes. Ansible inventory generated from
    `nix eval --json .#inventory`. Check whether the roles support
    Alpine (OpenRC). Hardware alerts only for devices with
    `baremetal = true`; new device field `category` (e.g. `network`,
    `proxmox-guest`, `pi`) to group tiles. win11 stays unmonitored.
4.  **Overview v2**: a recording rule computes a status per host:
    0 green, 1 yellow (a firing warning alert, or load without e-mail:
    CPU > 90 % for 15 min, RAM > 90 %, disk > 85 %, PSI pressure),
    2 red (a firing critical alert, HostDown). Tiles per host grouped by
    category, showing CPU, RAM and uptime (adjust after use); a state
    timeline below; click a tile -> new "Host detail" dashboard (status,
    the host's alerts, CPU/RAM/disk/network, failed units, temperatures,
    SMART and scrub on bare metal) -> Node Exporter Full / NVIDIA /
    Explore for that host. Native panels (Stat with data links), no
    plugins; Polystat only if wanted later.
5.  **pfSense, UPS, Wi-Fi routers**: - pfSense 2.7.2 (2.8.1 hangs on this box): the package node_exporter
    is known to fail with 'cannot allocate memory' in the uname and
    os collectors on 2.7.x (https://redmine.pfsense.org/issues/14452;
    fixed only in 24.11 Plus). Try the package with those two
    collectors disabled; install through the GUI package manager. - UPS: APC Back-UPS 850 (BE850G2-GR) on USB to pfSense, which runs
    NUT and tells Proxmox to shut down. nut_exporter on the monitoring
    server against pfSense's upsd (needs a NUT user and upsd listening
    on the LAN). Alerts: on battery, battery low, replace battery, UPS
    unreachable, load high. - Two ASUS RT-AX92U on gnuton firmware (Asuswrt-Merlin port): check
    whether SNMP is available; otherwise node_exporter from Entware,
    or ping only. Check whether per-client Wi-Fi traffic can be
    exported.
    5c. Service exporters (after 5b): Nextcloud (nextcloud-exporter), MariaDB
    (mysqld_exporter), Redis, Immich (built-in, `IMMICH_TELEMETRY_INCLUDE=all`),
    Caddy and GitLab (built-in), Podman if not done in 5b; dashboards in
    folders Overview, Hosts, Containers, Services, Network. No known
    exporter for Calibre and Ollama: HTTP probes only. Check whether
    Syncthing exposes Prometheus metrics. Later and optional:
    healthchecks.io, Cloudflare, any JSON API through the Infinity plugin.
6.  Class `managed` for family and friends' laptops (`keeper` admin account,
    Flathub and GNOME Software/KDE Discover for the user).
7.  Documentation: rewrite `README.md` (still describes `colmena.nix` and the
    removed `nixos-test` host) and add an architecture document.
=======
   5a covered the NixOS machines, ping of devices, websites and alerting;
   docs/MONITORING.md). Decided on 2026-10-02, in this order (the user's
   priority is Proxmox and containers):
   1. ~~Proxmox: prometheus-pve-exporter on altair~~: done on 2026-10-02
      (CHANGELOG.md).
   2. ~~Containers~~: done on 2026-10-03 (CHANGELOG.md): cAdvisor on the
      Docker hosts (through `nix run .#fleet`) and on altair for Podman,
      job `cadvisor` with label `runtime`, dashboard 14282. Left for step
      4: one own "Containers" dashboard that also shows Incus (and
      Proxmox guests from the pve exporter).
   3. **node_exporter on everything with Linux** (pve, Proxmox guests on
      Debian/Ubuntu/Rocky, walthpi, walthpi16), smartctl_exporter on the
      bare-metal ones. The machinery exists since step 2: add agents
      `node` and `smartctl` to "monitoring apply" in `nix run .#fleet`
      (a playbook each, device fields `monitoring.node`,
      `monitoring.smartctl`), plus a task "device add" that asks for a new
      device and writes `hosts/devices/<name>.nix`. The roles of the
      collection support only systemd distributions (Ubuntu, Debian, EL):
      Alpine guests (`alpine-mariadb`) stay at ping until they disappear
      in the migration to NixOS (decided 2026-10-03). Hardware alerts only for devices with
      `baremetal = true`; new device field `category` (e.g. `network`,
      `proxmox-guest`, `pi`) to group tiles. win11 stays unmonitored.
   4. **Overview v2**: a recording rule computes a status per host:
      0 green, 1 yellow (a firing warning alert, or load without e-mail:
      CPU > 90 % for 15 min, RAM > 90 %, disk > 85 %, PSI pressure),
      2 red (a firing critical alert, HostDown). Tiles per host grouped by
      category, showing CPU, RAM and uptime (adjust after use); a state
      timeline below; click a tile -> new "Host detail" dashboard (status,
      the host's alerts, CPU/RAM/disk/network, failed units, temperatures,
      SMART and scrub on bare metal) -> Node Exporter Full / NVIDIA /
      Explore for that host. Native panels (Stat with data links), no
      plugins; Polystat only if wanted later.
   5. **pfSense, UPS, Wi-Fi routers**:
      - pfSense 2.7.2 (2.8.1 hangs on this box): the package node_exporter
        is known to fail with 'cannot allocate memory' in the uname and
        os collectors on 2.7.x (https://redmine.pfsense.org/issues/14452;
        fixed only in 24.11 Plus). Try the package with those two
        collectors disabled; install through the GUI package manager.
      - UPS: APC Back-UPS 850 (BE850G2-GR) on USB to pfSense, which runs
        NUT and tells Proxmox to shut down. nut_exporter on the monitoring
        server against pfSense's upsd (needs a NUT user and upsd listening
        on the LAN). Alerts: on battery, battery low, replace battery, UPS
        unreachable, load high.
      - Two ASUS RT-AX92U on gnuton firmware (Asuswrt-Merlin port): check
        whether SNMP is available; otherwise node_exporter from Entware,
        or ping only. Check whether per-client Wi-Fi traffic can be
        exported.
5c. Service exporters (after 5b): Nextcloud (nextcloud-exporter), MariaDB
   (mysqld_exporter), Redis, Immich (built-in, `IMMICH_TELEMETRY_INCLUDE=all`),
   Caddy and GitLab (built-in), Podman if not done in 5b; dashboards in
   folders Overview, Hosts, Containers, Services, Network. No known
   exporter for Calibre and Ollama: HTTP probes only. Check whether
   Syncthing exposes Prometheus metrics. Later and optional:
   healthchecks.io, Cloudflare, any JSON API through the Infinity plugin.
6. Class `managed` for family and friends' laptops (`keeper` admin account,
   Flathub and GNOME Software/KDE Discover for the user).
7. Documentation: rewrite `README.md` (still describes `colmena.nix` and the
   removed `nixos-test` host) and add an architecture document.
8. **Repository management CLI** (requested 2026-10-02). One command that
   changes the repository for common tasks so nobody has to remember paths
   and dependencies: it asks for the new values, writes the files,
   validates (evaluation or `nix flake check`), `git add`s them and prints a
   ready-to-copy `git commit` command; it never commits by itself.
   Decided 2026-10-02:
   - run without arguments it shows the list of tasks with a one-line
     description each and lets you pick one (searchable, gum); tasks also
     run directly as subcommands for scripting;
   - one Nix file per item, as `hosts/machines/` and `hosts/devices/`
     already do: the tool creates files from templates and deletes them,
     never parses Nix, and adds no JSON/TOML data files. `hosts/websites.nix`
     becomes `hosts/websites/<name>.nix`;
   - bash and gum, like `new-host`;
   - built during stage 5b: first the device onboarding (5b) and website
     add/remove, then remove-host (below); `new-host` moves under it.
<<<<<<< ours
>>>>>>> theirs
=======
   Started 2026-10-03: `nix run .#fleet` with the task menu, "monitoring
   apply" and shortcuts to new-host, install-host, sops-config. Open: how
   a task changes a field of an existing hand-written file (e.g. enabling
   an agent in a device file) without parsing Nix: regenerate the whole
   file from its fields (comments would be lost), or open the file in
   `$EDITOR` at the right place and validate afterwards.
>>>>>>> theirs

## Stages after the refactor

- **Router swap.** OPNsense on the smaller Wyse 5070 (8 GB/64 GB) broke
  during an update and needs repair (removed from monitoring in stage
  5a, device file kept). Then: OPNsense replaces pfSense (repeat the
  Tailscale subnet router and the NUT/UPS setup there), and the bigger
  Wyse 5070 (16 GB/256 GB) is reinstalled with NixOS as an encrypted
  container server.
- **Proxmox to NixOS, with central logs.** Move the services of the
  Proxmox guests to altair as declarative NixOS services where possible,
  migrate Cloudflare Tunnel and Caddy from their Debian VMs, reinstall the
  Proxmox host with NixOS and add it to the fleet. Central log collection
  belongs to this stage, as declarative services on altair (e.g. Loki or
  VictoriaLogs) with agents on the remaining non-NixOS hosts (Debian,
  Ubuntu, Alpine, Rocky/FreeIPA, pfSense, Raspberry Pi). The
  documentation must state for every service what it is and where it
  runs (bare-metal service, container, VM, service in a VM).
- **Unattended LUKS unlock (Clevis + Tang).** NixOS has
  `boot.initrd.clevis` (Tang, TPM2 and Shamir combinations; falls back to
  the passphrase prompt). Plan: two Tang servers on the UPS, joined with
  SSS threshold 1, so either one unlocks: a dedicated small Raspberry Pi
  with wired Ethernet (Pi 4 2 GB preferred over Pi 3B+, whose 1 GB RAM
  cannot build anything), and possibly the RPi 5 that runs calibre -
  only after calibre is tagged or moved behind Cloudflare Tunnel (see
  "Tag the calibre Raspberry Pi"), because a compromised public service
  would expose the Tang keys. Back up the Tang keys (sops or backup); keep
  the passphrase and initrd SSH as the fallback. Check that clevis retries
  when Tang is not up yet after a long power cut. Optional: SSS with
  TPM2 + Tang to bind the disks to the board as well.
- **Second UPS for altair** (the current one cannot carry the GPUs); add
  it to monitoring and alerting like the first.
- **Documentation stage** (with stage 7): diagrams generated with
  nix-topology (https://github.com/oddlama/nix-topology, flake-parts
  module; reads services, microvm.nix guests and NixOS containers from
  the configurations, devices added by hand), per-host and per-service
  pages generated from `nix eval --json .#inventory` for the private
  org/Hugo documentation, hand-written notes only where nothing can be
  generated.
- **Audit export.** One command that collects a description of the whole
  infrastructure into a bundle for analysis and audit: for NixOS machines
  from the evaluated configurations (services, open ports, users,
  versions), for other hosts from Ansible facts plus package lists,
  services and listening ports. Build together with the documentation
  stage.

## Decisions to make before a stage

- **Automatic upgrades stay on azazel only** (decided 2026-09-30).
  `auto-upgrade.nix` runs `nix flake update` and commits `flake.lock` on the
  host itself; on several hosts this produces diverging lockfile commits.
  Options for later: one updater host chosen in the inventory while the
  others only pull and rebuild; hosts updating without writing the lockfile
  (not reproducible); a central updater (e.g. altair) that the workstations
  pull from.
- **Incus instances are not declarative.** The Incus preseed is applied only
  at the first `incus admin init` and never covers instances. Options:
  microvm.nix for NixOS guests (Incus stays for non-NixOS and OCI), OpenTofu
  with the Incus provider, or a custom reconcile service. Decide before
  moving the LXC containers from Proxmox.
- **Lint hooks.** Enable statix and deadnix in `parts/dev.nix` after a
  one-time cleanup of the existing code.

- **NixOS 26.11: restarts from the activation script.** Rebuilds warn
  that restarting or reloading systemd units from the activation script is
  deprecated and will be removed in 26.11. Likely source: sops-nix
  `restartUnits = ["NetworkManager.service"]` on `wifi-env-file`
  (`modules/system/wifi.nix`). Find every source (`grep -rn
'restartUnits\|reloadUnits' --include=*.nix .`, the rebuild output
  around the warning), then switch sops-nix to systemd-based activation if
  the locked version has it, update sops-nix, or drop `restartUnits`.
  Before upgrading to 26.11.
- **Two git remotes.** GitLab (`origin`) and GitHub diverged twice: an
  edit made on GitHub, and a rebase over pushed commits. Choose one way of
  working: GitLab only with a push mirror to GitHub (GitHub read-only), or
  a rule never to edit on GitHub. Decide together with "Repository
  privacy".

## Small fixes collected during the refactor

One pass when the refactor is done (or sooner, between stages).

- **yazi config rejected** (seen 2026-10-02 on azazel): 'TOML parse error
  at line 7 ... [[open.rules]] at least one of `url` or `mime` must be
  specified'. yazi 26.5 renamed the rule field `name` to `url`; the first
  rule in `modules/groups/cli/yazi.nix` still uses `name = "*/"`. yazi then
  ignores the whole file and runs with its presets: Enter opens files with
  the desktop default (GNOME Text Editor) instead of the `edit` opener, and
  the other settings (ratio, sorting, hidden files) are lost. After the fix
  check: the `edit` opener runs `vim` (is it nixvim's alias on every
  host?), and the preview pane shows file contents (on 2026-10-02 it showed
  only "File Type Classification: ASCII text" for BACKLOG.md).

- **Starship shows a red "⬢ [Systemd]" on cloud-apps.** Starship's
  `container` module: inside an LXC container systemd writes
  `/run/systemd/container`, and starship names anything it does not
  recognise there "Systemd" (red is the module's default style). The
  information is right (the shell runs in a container), the label is
  not helpful. In `modules/home/admin/starship.nix`: either
  `container.format` with a fixed label such as LXC on class `virtual`,
  or `container.disabled = true`.

## Repository cleanup

- **Dead files.** The repository still holds files nothing uses: modules
  no host imports, stale commented-out imports (e.g. the "Phase 4+" block
  in `hosts/physical/altair/configuration.nix`: Prometheus and Grafana
  already come in through `monitoring/default.nix`, `psu-monitor.nix` does
  not exist), scripts and documents left from earlier setups. Stage 1 removed the obvious ones. Do one pass after the
  refactor: list every `.nix` file under `modules/` and `hosts/` that no
  host evaluates (compare the files in the tree with the imports of all
  `nixosConfigurations`), grep for commented imports and for paths that
  do not exist, remove them with the system derivations of all hosts
  unchanged, and record what went in the changelog. Documents are covered
  by "Documents still to review" below.

## Follow-ups from stage 5a

- **Grafana "Export as image" fails** in the browser with "Failed to
  fetch"; the renderer receives no render request and Grafana logs no
  error. Likely cause (not verified): `server.root_url` is unset, so
  Grafana builds absolute URLs with its default `http://localhost:3000`,
  and the browser on the laptop fetches its own localhost. Check the
  failing request's URL in the browser's developer tools (Network tab);
  if it points to localhost, set `root_url = "http://192.168.50.150:3000/"`
  in grafana.nix (until Phase B gives grafana.home.lan). Update
  2026-10-02: `root_url` is now set (`http://altair.home.lan:3000/`); test
  again, and if it still fails look at the request in the Network tab. No browser
  extension is needed. The same setting fixes the "View in Alertmanager"
  and "Source" links in alert e-mails only partly: those come from
  Alertmanager's and Prometheus' own external URLs, which are loopback.
- **NVMe not seen by smartctl_exporter**: only `sda` (Toshiba HDD)
  appears; the NVMe drive is missing, so NvmeCriticalWarning,
  NvmeWearHigh and its DiskTemperatureHigh never fire. Check
  `journalctl -u prometheus-smartctl-exporter`, whether the unit's device
  sandbox lets it open `/dev/nvme0`, and the module's `devices` option.
- **Placeholder website** `example-public` in `hosts/websites.nix`:
  replace with the real public pages.
- **Network traffic per host**: the switch (Cudy GS1016) is unmanaged, so
  traffic inside the LAN is visible only from exporters on the hosts.
  Per-client internet traffic comes with OPNsense's NetFlow and Insight
  after the router swap (decide then whether Insight is enough or flows go
  to Grafana). A managed rack switch is planned in some months: then
  per-port counters over SNMP.
- **Backups after Proxmox**: Proxmox backup e-mails work today; when the
  Proxmox host becomes NixOS, the backup setup has to be rebuilt.

- **`autodefrag` on altair's `/mnt/data`** (backup target): breaks
  reflinks and inflates snapshot space. Decide with the backup design.
- **GPU memory alert removed.** The old rule (VRAM > 95 %) would fire
  whenever Ollama keeps a large model loaded, which is normal. Add a
  meaningful GPU memory alert if one is needed (e.g. for OOM errors in
  Ollama's log once logs are collected).
- **Alertmanager UTF-8 mode.** Matchers are written in the classic syntax;
  consider `--enable-feature=utf8-strict-mode` after `amtool check-config`
  shows no warnings.

- **Proxmox certificate renewal.** pveproxy serves a FreeIPA certificate
  (`pveproxy-ssl.pem`, valid until 2027-09-13), probably uploaded by
  hand; check whether anything renews it. The probe `pve-web` warns 14 days ahead. Renew through
  FreeIPA (or certmonger on the host) before then, or the pve exporter
  stops (PveExporterDown).
- **Atuin server on an untagged image.** The container on the Docker VM
  runs image `027f8688c923` (shown without a name: its tag now points
  elsewhere or is gone), 11 months old; clients run 18.15.2 (nixpkgs
  26.05). `atuin.home.lan` resolves to the Caddy VM (192.168.50.114), which
  proxies to the Docker VM. The server reports version 18.8.0; the image
  (`ghcr.io/atuinsh/atuin:latest`) was built on 2025-08-04; its data is in
  the Docker volume `atuin_atuin-data` (`/data`). Decided 2026-10-02:
  move it to altair as the native NixOS service `services.atuin` (same
  package as the clients, upgraded with flake.lock), not a container. The
  move only needs Caddy's upstream changed (`reverse_proxy` in the `atuin`
  block on the Caddy VM) and port 8888 on altair opened to the Caddy VM;
  it can wait for the Caddy migration. The module defaults to PostgreSQL;
  if the old server uses SQLite, start with an empty server and push the
  store from one client instead of migrating the database. Combine with
  the Atuin items under "Follow-ups from stage 1" (key rotation, separate
  account for servers, workstation login from sops).
- **Stopped Proxmox guests outside backups**: `lxc/108` (stopped) and
  `lxc/9000` (stopped, maybe a template) are in no backup job. Decide per
  guest: add to a backup job, tag `nobackup` in Proxmox (PveGuestNotBackedUp
  skips it), or delete it.

## Follow-ups from stage 4

- **Finish stage 4 on sukkub and baal.** Rebuild both, delete any
  hand-made hotspot profile first, run `tailscale-join`, then record the
  remaining checks in the stage 4 changelog entry (Verification).
- **pfSense is the subnet router, configured by hand** (package, tagged
  key, advertised route; `docs/REMOTE-ACCESS.md`). Repeat it on OPNsense
  when pfSense is replaced.
- **Direct connections to pfSense.** From a phone hotspot the laptop
  reaches pfSense only through the DERP relay in Warsaw (works, ~100-200
  ms, limited throughput). pfSense sits behind the provider's NAT (roof
  antenna, no access), and a WAN rule for UDP 41641 did not help (no
  matches, removed; Advertise Exit Node switched off). Option once the
  VPS exists: run a Tailscale peer relay on it, so both ends connect to a public node instead of DERP
  (`docs/REMOTE-ACCESS.md`, "Relayed instead of direct connections").
- **systemd-resolved on bad networks.** On the phone hotspot resolved
  stalled: unreachable IPv6 DNS servers announced by the phone, and its
  DNS proxy made resolved fall back from EDNS0 on every reconnect, so
  lookups timed out while `dig`/`host` answered at once. Fixed for the
  hotspot profile in `modules/system/wifi.nix` (IPv6 off, 9.9.9.9 and
  1.1.1.1). On another network with the same symptom: `sudo resolvectl dns
<interface> 9.9.9.9 1.1.1.1`; if it keeps happening, look for a general
  fix (resolved has no "prefer IPv4" or "skip EDNS0" setting).
- **Tag the calibre Raspberry Pi.** It publishes calibre with Funnel and is
  an untagged device of marcin's, so the tailnet policy lets it start
  connections to the whole tailnet and, through the subnet router, to the
  home LAN. A compromise of the published service would reach everything.
  Re-authenticate it with a tag (e.g. `tag:funnel`), give the `funnel`
  attribute to the tag in `nodeAttrs` and no `src` rule to the tag. Moot
  once calibre moves to Cloudflare Tunnel (see Infrastructure).
- **Firewall on `tailscale0`.** Workstations trust the interface
  (`networking.firewall.trustedInterfaces`); the tailnet policy is the
  only filter. Replace with explicit ports once it is clear which services
  must be reachable over the tailnet.
- **`join = "tagged"` is untested.** `install-host` hands over the key
  and `tailscale-join-once` uses it, but no tagged machine exists yet.
  Test with the first managed computer (stage 6), together with the
  `tag:managed` rule for the Atuin server in the tailnet policy.
- **Servers stay off the tailnet.** A server gets its own Tailscale only to
  publish a service with Funnel when the service has no Cloudflare Tunnel;
  it then needs a `tailscale` entry with `join = "tagged"` and a tagged key.

## Follow-ups from stage 2

- **Encrypted host list.** After the move to `hosts/devices/`, the
  `ssh_config` value in `secrets/users/marcin/admin.yaml` should hold only
  hosts that must not be in the repository (e.g. mydevil.net). Revisit once
  the repository is private.
- **`base-baremetal.nix` is still shaped by altair.** The address and the
  interface now come from the inventory, but gateway/DNS (`.1`), the CUDA
  cache and initrd SSH (needs its own host key on the machine) apply to
  every bare-metal server. Split before the next server.
- **Documents still to review** (stage 7). Removed on 2026-10-01 as
  superseded: SSH_KEYS_SETUP, SSH_MIGRATION, POST-INSTALL-SOPS-SETUP,
  INSTALLATION, FIX-WIFI-ENV-VARIABLES; logs moved to `docs/history/`.
  Left to check against the current repository: `docs/WIFI_SETUP.md`
  (mechanism still current, details may not be),
  `docs/DEPLOY-MULTIPURPOSE-SERVER.org` and `docs/SERVER-DEPLOYMENT.org`
  (January 2026, before Colmena and the inventory; probably superseded),
  the four overlapping nixvim/neovim documents (merge into one), and the
  rest of README.md.
- **`new-host` for aarch64.** The script writes `x86_64-linux` only; the
  Raspberry Pis need `meta.nodeNixpkgs` in the hive first.
- **NVIDIA on sukkub** (removed 2026-09-30). With the legacy_470 driver
  GNOME could not render (GBM errors on the NVIDIA card) and
  suspend-then-hibernate failed ('without driver procfs suspend
  interface': nvidia-suspend did not run for that sleep mode). To bring it
  back: keep the Intel GPU as Mutter's only display device (check which
  udev tag Mutter honours), hook nvidia-suspend/resume into
  systemd-suspend-then-hibernate, test nvidia-offload.
- **sukkub boots into emergency mode** (2026-09-30, after removing the
  NVIDIA driver); Enter continues the boot. Not investigated. Start with
  `systemctl --failed` and `journalctl -b -p err` (likely a mount or a
  unit required by local-fs.target).
- **Atuin on sukkub before first use** (sukkub is off and treated as out
  of service since 2026-10-02). It has the fleet key since 2026-09-30, but
  it missed the repair of 2026-10-02 (`store pull --force`). If it synced
  between 2026-10-01 09:00 UTC (baal's first records) and that repair, its
  local store may hold baal's undecryptable records and upload them again.
  First thing after booting it, in a terminal:
  `systemctl --user stop atuin-daemon.socket atuin-daemon`, then
  `atuin store verify`; if that fails, `atuin store purge && atuin store verify`;
  then `atuin sync` and start the socket again. Its next rebuild brings
  `atuin-auto-login-marcin`, which checks the key on every boot.

## Follow-ups from stage 1

- **Signed deployments instead of trusted users.** Workstations trust
  `@wheel` in the Nix daemon (so `nixos-rebuild --target-host` from azazel
  works). Replace with a signing key on azazel (private key in sops,
  `nix.settings.secret-key-files`) and its public key in
  `trusted-public-keys` on every host, together with the `deploy` account.
- **Hibernation on baal does not resume.** `systemctl hibernate` powers
  off, but the next boot starts a fresh session instead of restoring the
  old one (`hosts/workstations/baal/hibernate.nix`: resume device
  `/dev/mapper/cryptroot`, `resume_offset=533760`). To check: after
  booting, `cat /sys/power/resume /sys/power/resume_offset`; the previous
  boot's log (`journalctl -b -1 | grep -i -E 'hibernat|resume|PM:'`);
  whether the scripted initrd tries to resume after unlocking LUKS
  (maybe `boot.initrd.systemd.enable` is needed); the offset against
  `btrfs inspect-internal map-swapfile -r`.
- **`remove-host`: retire a machine cleanly.** Counterpart of `new-host`
  for a machine that is gone: removing it from the repository shows at
  once (evaluation, `nix flake check`) whether anything else still
  depends on it, which should not happen, and keeps the configuration
  tidy. Wanted: the removed configuration stays available to read or to
  restore. Proposed design (decide when implementing):
  - delete `hosts/machines/<host>.nix`, the host directory and
    `secrets/hosts/<host>/`, run `nix run .#sops-config` (the host's key
    leaves every secret file; known_hosts and ssh config follow by
    themselves), evaluate the fleet;
  - before deleting, create an annotated git tag `removed/<host>` on the
    last commit that has the host (date and reason in the message) and
    add a line to a list of retired hosts (`hosts/REMOVED.md`: name,
    date, tag, reason);
  - restore: `git checkout removed/<host> -- <paths>`, then `new-host`
    style registration of the key.
    Why a tag rather than an archive directory in the tree: archived Nix
    files are no longer evaluated, so they silently stop matching the
    modules they import and are not restorable as they are; the tag keeps
    the host together with the exact modules it was built with. An archive
    directory would also have to be excluded from every loader and check.
    Secrets the host could read stay readable in git history: rotate them
    if the machine left the house rather than being scrapped.
- **Declarative Syncthing.** Folders and devices are set in the web GUI and
  are not in the repository. NixOS `services.syncthing.settings.devices` /
  `.folders` with `overrideDevices` / `overrideFolders = false` should keep
  GUI additions working next to the declared ones (verify in the NixOS
  options before relying on it). Needs a one-off import of the current
  `~/.config/syncthing/config.xml` into Nix.
- **`rdp-win11` passes the password on the command line** (`xfreerdp /p:`),
  readable by every local user in `/proc/<pid>/cmdline`. Check whether
  FreeRDP can read the password from stdin or a file.
- **Keyboard layout is system-wide.** `modules/system/locale.nix` sets the
  Polish layout and `ctrl:nocaps` for every workstation user; marcin's
  GNOME copy of it is personal (`users/marcin/home/gnome.nix`). Decide
  per user before friends' laptops (stage 6).
- **Atuin for `keeper`** (stage 6): a separate Atuin account whose
  credentials only the device and the admin key can decrypt, and a tailnet
  ACL entry that lets managed devices reach the Atuin server only.
- **Server package lists overlap the `cli` group.** `base-lxc.nix` and
  `base-baremetal.nix` still install btop, curl, eza, zoxide, starship,
  atuin etc. system-wide. Trim them when the servers are reworked.
- **Size of the admin base on small machines.** nixvim brings all
  tree-sitter grammars, two language servers and formatters (prettier pulls
  Node.js). Measure on the Wyse 5470 (128 GB disk) in stage 3.
- **`btrfs-writing-monitor` on other laptops.** It comes with
  `modules/system/btrfs.nix`, which needs the writing subvolumes of the
  host's disk layout; add it to sukkub or the Wyse together with that
  layout.
<<<<<<< ours
- **Atuin key on workstations from sops.** Servers log in with the key from
  `secrets/atuin-key.txt`; workstations log in by hand, which let an old
  host sync records under a different key ('attempting to decrypt with
  incorrect key', repaired on 2026-09-30 with store purge / push --force /
  pull --force). Log workstations in from sops as well; the generated
  `.sops.yaml` then adds them to the Atuin files automatically (stage 2
  removed sukkub from them because nothing on sukkub used them).
  Happened again on 2026-10-02: baal (installed 2026-10-01) logged in by
  hand with its own key.
=======
>>>>>>> theirs
- **Rotate the Atuin encryption key.** The current key (in
  `secrets/atuin-key.txt`) was exposed in a chat transcript on 2026-09-30.
  Generate a new key, re-encrypt the store on one host, push it with
  `atuin store push --force`, update the sops secret, and log every host in
  again. Check first which rekey command Atuin 18.15 offers.
- **One Atuin account for all hosts.** Every host, including the
  internet-facing cloud-apps, holds the credentials of the `admin` Atuin
  account, which contains the shell history of all hosts. Root on any host
  can read everyone's history, including secrets ever typed on a command
  line. Options: a separate Atuin account for servers, a review of
  `history_filter`.

## Infrastructure (outside this repository or later stages)

- New services in this repository use Cloudflare Tunnel for public
  exposure by default (migration of the existing Cloudflare Tunnel and
  Caddy VMs: stage "Proxmox to NixOS").
- Calibre on a Raspberry Pi is published with Tailscale Funnel; consider
  moving it behind Cloudflare Tunnel as well.
- Tailnet access policy (ACL) is managed manually in the Tailscale admin
  console for now (draft in `docs/REMOTE-ACCESS.md`). Consider
  policy-as-code (policy file in a repository, applied automatically)
  later.
- **Headscale**, together with a VPS (worth having anyway). Known
  constraints: it does not work behind Cloudflare Proxy or Cloudflare
  Tunnel (it needs a direct public address with TLS, e.g. the VPS);
  Funnel, Serve and network flow logs are not implemented, so calibre must
  leave Funnel first; one tailnet only, so machine sharing between
  tailnets does not exist (`join = "shared"` machines stay on Tailscale);
  clients must be among the last 10 Tailscale releases; a client talks to
  one control server at a time. Switch with `tailscale.loginServer` in
  `hosts/fleet.nix`, then `tailscale-join` on every machine. The same VPS
  can run a Tailscale peer relay (see "Direct connections to pfSense").
- Raspberry Pi 5 machines (aarch64) - add to the fleet later; needs
  `meta.nodeNixpkgs` in the Colmena hive and a build strategy.
- Backups: the Proxmox backup (vzdump) does not include bind mounts, so
  `/mnt/bigstorage` (Nextcloud data, databases, dumps) has no copy on
  another disk.
- Nextcloud 32 -> 33 upgrade as a separate operation with its own backup.
- **External probes from mydevil.net** (shell account, no root): a cron
  job that fetches the public pages and pings a healthchecks.io check on
  success, so outages seen from outside are reported too. Possibly also
  replace healthchecks.io for the Watchdog with a small PHP endpoint plus
  a cron freshness check there.
- **Alert mail relay**: direct delivery from altair works to the own
  domain (waltharius.pl) but is rejected by Proton Pass aliases, because
  the sender domain `home.lan` does not exist publicly. Relay Postfix
  through an authenticated mailbox (e.g. on mydevil.net, password in sops,
  `texthash:` map) with a real sender address, so delivery no longer
  depends on the receiving server's tolerance.

## Repository privacy

The repository is public. Evaluation-time data (LAN addresses, host names,
deployment targets) cannot be encrypted with sops, because sops decrypts on
the host at activation time, after evaluation.

- Make the repository private (planned).
- Review what is already exposed in the git history. Encrypting or removing
  data now does not remove it from history or from existing clones.
- Evaluate options (private repository only, history rewrite, git-crypt)
  and decide whether further hardening is worth it for this setup.
