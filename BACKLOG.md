# Backlog

Work that was deliberately postponed while refactoring the repository.
Each item says why it waits and what has to be decided first. When an item
is done, move it to `CHANGELOG.md` together with its lessons learned.

## Refactor stages still ahead

3. Installation with nixos-anywhere (first target: Dell Wyse 5470, baal):
   `nix run .#install-host` is written (LUKS, writing subvolumes, 8 GiB
   swap file). Remaining: install baal, then hibernation on baal (resume
   device and `resume_offset` of the swap file are known only after the
   install), measure the size of the admin base on the 128 GB disk.
4. Remote access (Tailscale on every host, subnet router for the LAN).
5. Monitoring: generated scrape targets for servers, push for laptops,
   Alertmanager.
6. Class `managed` for family and friends' laptops (`keeper` admin account,
   Flathub and GNOME Software/KDE Discover for the user).
7. Documentation: rewrite `README.md` (still describes `colmena.nix` and the
   removed `nixos-test` host) and add an architecture document.

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

## Follow-ups from stage 2

- **SSH host keys of existing hosts.** `ssh.hostKey` is empty for azazel,
  sukkub, altair and cloud-apps, so they are not pinned in
  `/etc/ssh/ssh_known_hosts` yet (see `docs/SSH.md`). Same for the devices
  in `hosts/devices.nix` and the initrd key of altair.
- **Encrypted host list.** After the move to `hosts/devices.nix`, the
  `ssh_config` value in `secrets/users/marcin/admin.yaml` should hold only
  hosts that must not be in the repository (e.g. mydevil.net). Revisit once
  the repository is private.
- **`base-baremetal.nix` is still shaped by altair.** The address and the
  interface now come from the inventory, but gateway/DNS (`.1`), the CUDA
  cache and initrd SSH (needs its own host key on the machine) apply to
  every bare-metal server. Split before the next server.
- **Old SSH and sops documents** (`docs/SSH_KEYS_SETUP.md`,
  `docs/SSH_MIGRATION.md`, `docs/POST-INSTALL-SOPS-SETUP.md`) describe the
  manual process from before stage 2. Rewrite or remove in stage 7.
- **`new-host` for aarch64.** The script writes `x86_64-linux` only; the
  Raspberry Pis need `meta.nodeNixpkgs` in the hive first.
- **NVIDIA on sukkub** (removed 2026-09-30). With the legacy_470 driver
  GNOME could not render (GBM errors on the NVIDIA card) and
  suspend-then-hibernate failed ('without driver procfs suspend
  interface': nvidia-suspend did not run for that sleep mode). To bring it
  back: keep the Intel GPU as Mutter's only display device (check which
  udev tag Mutter honours), hook nvidia-suspend/resume into
  systemd-suspend-then-hibernate, test nvidia-offload.

## Follow-ups from stage 1

- **Signed deployments instead of trusted users.** Workstations trust
  `@wheel` in the Nix daemon (so `nixos-rebuild --target-host` from azazel
  works). Replace with a signing key on azazel (private key in sops,
  `nix.settings.secret-key-files`) and its public key in
  `trusted-public-keys` on every host, together with the `deploy` account.
- **Hibernation on baal.** Swap file exists (8 GiB); resume device and
  `resume_offset` still to be configured.
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
- **Atuin key on workstations from sops.** Servers log in with the key from
  `secrets/atuin-key.txt`; workstations log in by hand, which let an old
  host sync records under a different key ('attempting to decrypt with
  incorrect key', repaired on 2026-09-30 with store purge / push --force /
  pull --force). Log workstations in from sops as well; the generated
  `.sops.yaml` then adds them to the Atuin files automatically (stage 2
  removed sukkub from them because nothing on sukkub used them).
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

- Migrate Cloudflare Tunnel and Caddy from the Debian VMs on Proxmox
  (installed with the Proxmox helper scripts) to NixOS. New services in this
  repository use Cloudflare Tunnel for public exposure by default.
- Calibre on a Raspberry Pi is published with Tailscale Funnel; consider
  moving it behind Cloudflare Tunnel as well.
- Tailnet access policy (ACL) is managed manually in the Tailscale admin
  console for now. Consider policy-as-code (policy file in a repository,
  applied automatically) later.
- Add Headscale next to Tailscale.
- Reinstall the Proxmox host with NixOS and move its containers to altair
  (separate stage).
- Raspberry Pi 5 machines (aarch64) - add to the fleet later; needs
  `meta.nodeNixpkgs` in the Colmena hive and a build strategy.
- Central log collection for analysis and reporting.
- Backups: the Proxmox backup (vzdump) does not include bind mounts, so
  `/mnt/bigstorage` (Nextcloud data, databases, dumps) has no copy on
  another disk.
- Nextcloud 32 -> 33 upgrade as a separate operation with its own backup.
- Rotate Grafana's `secret_key` (currently the publicly known pre-26.05
  default).

## Repository privacy

The repository is public. Evaluation-time data (LAN addresses, host names,
deployment targets) cannot be encrypted with sops, because sops decrypts on
the host at activation time, after evaluation.

- Make the repository private (planned).
- Review what is already exposed in the git history. Encrypting or removing
  data now does not remove it from history or from existing clones.
- Evaluate options (private repository only, history rewrite, git-crypt)
  and decide whether further hardening is worth it for this setup.
