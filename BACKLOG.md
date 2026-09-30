# Backlog

Work that was deliberately postponed while refactoring the repository.
Each item says why it waits and what has to be decided first. When an item
is done, move it to `CHANGELOG.md` together with its lessons learned.

## Refactor stages still ahead

2. Per-host sops keys and a `new-host` script.
3. Installation with nixos-anywhere (first target: Dell Wyse 5470).
4. Remote access (Tailscale on every host, subnet router for the LAN).
5. Monitoring: generated scrape targets for servers, push for laptops,
   Alertmanager.
6. Class `managed` for family and friends' laptops (`keeper` admin account,
   Flathub and GNOME Software/KDE Discover for the user).
7. Documentation: rewrite `README.md` (still describes `colmena.nix` and the
   removed `nixos-test` host) and add an architecture document.

## Decisions to make before a stage

- **Stage 2 scope** (decided 2026-09-30): existing hosts keep their age key
  files; new hosts derive their age key from the SSH host key. Exceptions
  to decide: azazel (its host key equals the admin key) and cloud-apps
  (servers-shared key, Nextcloud is internet-facing).
- **`.sops.yaml` generated from the inventory**: age public key per host,
  secret audiences by host/class/tag, `nix flake check` fails on drift,
  `sops updatekeys` after audience changes. Remove sukkub from the Nextcloud
  and MariaDB secrets.
- **`new-host` script** (`nix run .#new-host`): part A (register host,
  keys, files, sops, evaluation) in stage 2, part B (nixos-anywhere install
  with pre-generated SSH host key) in stage 3 on baal. Open: inventory as
  one file per machine, storing host private keys encrypted in the repo,
  plain bash vs gum prompts.
- **Identical systems from Colmena and nixos-rebuild**: add the flake
  metadata of lib.nixosSystem to Colmena nodes; verify equal drvPaths for
  every host.
- **Auto-upgrade stays on azazel only** for now.
- **Incus instances are not declarative.** The Incus preseed is applied only
  at the first `incus admin init` and never covers instances. Options:
  microvm.nix for NixOS guests (Incus stays for non-NixOS and OCI), OpenTofu
  with the Incus provider, or a custom reconcile service. Decide before
  moving the LXC containers from Proxmox.
- **Lint hooks.** Enable statix and deadnix in `parts/dev.nix` after a
  one-time cleanup of the existing code.
- **Non-NixOS devices in the address plan.** The inventory validates only
  NixOS machines. Devices such as OPNsense (`192.168.50.149`) or the
  Windows 11 VM (`192.168.50.6`, used by `rdp-win11`) are not checked for
  conflicts. Consider a list of reserved addresses in the inventory.

## Follow-ups from stage 1

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
  pull --force). Log workstations in from sops as well.
- **Rotate the Atuin encryption key.** The current key (in
  `secrets/atuin-key.txt`) was exposed in a chat transcript on 2026-09-30.
  Generate a new key, re-encrypt the store on one host, push it with
  `atuin store push --force`, update the sops secret, and log every host in
  again. Check first which rekey command Atuin 18.15 offers.

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
