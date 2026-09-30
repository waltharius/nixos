# Changelog

All notable changes to this repository are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The repository has no releases, so entries are grouped by date and refactor
stage instead of version numbers. Every entry ends with **Lessons learned**:
what went wrong, what was surprising, and what should be done differently
next time. Changes that were reverted stay in the log together with the
reason for reverting them.

## [Unreleased] Refactor stage 3 - installing hosts (baal)

### Added

- `nix run .#install-host -- <host> root@<address>`
  (`scripts/install-host.sh`): installs a host registered with `new-host`
  using nixos-anywhere, with the stored SSH host key, the LUKS passphrase
  handed to the installer and `hardware-configuration.nix` generated on
  the target.
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

### Fixed

- `buku-auto-export` ran `~/.nix-profile/bin/buku-export`, which does not
  exist when Home Manager installs into `/etc/profiles/per-user/<user>`.

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
