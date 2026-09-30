# Backlog

Work that was deliberately postponed while refactoring the repository.
Each item says why it waits and what has to be decided first. When an item
is done, move it to `CHANGELOG.md` together with its lessons learned.

## Refactor stages still ahead

1. Host groups and a shared shell module for all accounts (includes moving
   ble.sh, starship, atuin and zoxide in `modules/home/shell/bash.nix` behind
   the interactive-shell guard).
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

- **Colmena vs `nixos-rebuild` builds differ** (flake metadata, see
  CHANGELOG stage 0). Decide whether to add the nixpkgs flake metadata to
  Colmena nodes as well, so both tools build the identical system. Changes
  every server's system label once.
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
