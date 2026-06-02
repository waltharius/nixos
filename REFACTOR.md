# NixOS Repository — Refactoring Log

This document is the living record of every intentional structural change made
to the repository. It replaces speculative planning with a factual history:
each completed phase is marked ✅, known pending work is listed at the bottom.

---

## Phase 1 — Server Infrastructure (completed)

Restructured the server side of the repository to support scalable,
Colmena-based deployment of Proxmox LXC containers.

**Key outcomes:**
- `hosts/servers/` replaces the old `hosts/containers/`
- `modules/servers/base-lxc.nix` provides a common baseline for every container
- `modules/servers/roles/` holds opt-in service modules (`actual-budget.nix`, …)
- `users/nixadm/` — dedicated admin user; root SSH disabled on all servers
- `colmena.nix` — single-file deployment manifest with tag-based targeting
- Shared SOPS key (`&servers-shared`) so every LXC can decrypt secrets without
  per-host re-encryption
- Proxmox template (ID 9000) for 5-minute new-server provisioning
- `scripts/create-server-from-template.sh` — automation helper

**Deployment workflow:**
```bash
colmena apply --on <hostname>   # single host
colmena apply --on @production  # by tag
colmena apply                   # all hosts
```

**Adding a new server:**
1. Clone template: `./scripts/create-server-from-template.sh <name> <id> <ip>`
2. Add entry to `colmena.nix`
3. Create `hosts/servers/<name>/configuration.nix` importing `base-lxc.nix` and
   the desired role module(s)
4. `colmena apply --on <name>`

---

## Phase 2 — Workstation `profile.nix` (completed)

Decoupled per-host feature selection from hardware configuration.
Previously, `configuration.nix` on each workstation imported every module
directly. Now the split is:

| File | Purpose |
|------|---------|
| `hosts/workstations/<host>/configuration.nix` | Hardware only (filesystem, kernel, networking, locale) |
| `hosts/workstations/<host>/profile.nix` | Feature selection — the only file to edit when enabling/disabling a module |
| `hosts/workstations/<host>/tlp.nix` | Per-host TLP power tuning |
| `hosts/workstations/<host>/hibernate.nix` | Per-host hibernate/suspend policy |

**`flake.nix`** calls `mkHost` which automatically imports `profile.nix`,
so no other file changes when a new workstation is added.

**Adding a new workstation:**
1. Create `hosts/workstations/<name>/` with `configuration.nix`,
   `hardware-configuration.nix`, `profile.nix`, `tlp.nix`, `hibernate.nix`
2. Add the host to `flake.nix` with `mkHost`
3. Add `users/marcin/profiles/<name>.nix` (see Phase 4)
4. That is all — no other file needs to change

---

## Phase 3 — Dead file cleanup (completed)

Removed modules that were superseded by the per-host split in Phase 2:

- ~~`modules/laptop/tlp.nix`~~ — replaced by `hosts/workstations/*/tlp.nix`
- ~~`modules/laptop/hibernate.nix`~~ — replaced by `hosts/workstations/*/hibernate.nix`

`modules/laptop/` now contains only actively-imported modules:
`acpi-fix.nix`, `acpi-suspend.nix`, `fingerprint.nix`, `nvidia.nix`,
`suspend-fix.nix`, `thunderbolt.nix`, `thunderbolt-coldboot-fix.nix`,
`thunderbolt-hibernate-fix.nix`.

---

## Phase 4 — Home Manager modularisation (completed)

Split the 300-line `users/marcin/home.nix` monolith into focused modules.

### New structure

```
users/marcin/
├── home.nix                    # entry point — identity, sops, imports
├── base/                       # identical on every host
│   ├── git.nix                 # programs.git identity & settings
│   ├── fonts.nix               # fontconfig + custom font symlink
│   ├── packages.nix            # all home.packages
│   ├── environment.nix         # sessionVariables
│   ├── nextcloud.nix           # Nextcloud sync-exclude.lst
│   ├── autostart.nix           # XDG autostart .desktop entries
│   ├── solaar.nix              # Logitech MX Keys S + MX Master 3S config
│   └── desktop-extensions.nix # marcin.desktop option — see below
└── profiles/
    ├── azazel.nix              # marcin.desktop = "gnome"
    └── sukkub.nix              # marcin.desktop = "gnome" (niri-ready)
```

### `marcin.desktop` — per-host DE selection

`desktop-extensions.nix` declares a custom NixOS option:

```nix
options.marcin.desktop = lib.mkOption {
  type = with lib.types; either str (listOf str);
  default = [];
};
```

Each host profile sets this option. The module then activates only the
configuration blocks that belong to the listed DE(s).

**Adding a new desktop environment (e.g. Sway, Hyprland):**
1. Add a feature flag in `desktop-extensions.nix`:
   ```nix
   sway = lib.elem "sway" desktops;
   ```
2. Add a `lib.mkIf sway { … }` block with the packages and config files
   needed by that DE.
3. In the host profile set:
   ```nix
   marcin.desktop = "sway";          # single DE
   marcin.desktop = [ "gnome" "sway" ]; # both active simultaneously
   ```
4. No other file changes.

**Switching sukkub to niri:**
Edit `users/marcin/profiles/sukkub.nix`:
```nix
marcin.desktop = "niri";          # niri only
# or
marcin.desktop = [ "gnome" "niri" ]; # both
```
Then fill in the niri block in `base/desktop-extensions.nix`.

---

## Pending / Backlog

Items noted during the refactoring sessions, to be addressed in future sessions.

### Short term

- [ ] **`services.secrets.enable` default** — evaluate making it `true` by
  default in `modules/system/secrets.nix` since every workstation enables it;
  discuss trade-offs (bootstrap, server hosts that don't use it)

- [ ] **Yazi issues** (regression from recent config changes):
  - TOML parse error at startup (`[[open.rules]]` missing `url`/`mime`)
  - Right-column preview not working
  - `README.md` opens in OnlyOffice instead of Neovim
  - Folder icons showing as ANSI characters instead of Nerd Font glyphs

- [ ] **NVIDIA on sukkub** — verify driver and power management after full
  reboot; no errors observed yet but not stress-tested

### Medium term

- [ ] **Flatpak auto-update on laptops** — investigate `nix-flatpak`
  `services.flatpak.update.auto.enable`; assess safety (no Nix rollback for
  Flatpak apps, acceptable for Signal/Spotify/Brave)

- [ ] **Niri setup on sukkub** — fill in the niri block in
  `base/desktop-extensions.nix` (packages: niri, waybar, mako, swaylock, …)
  and test Wayland-native workflow

### Long term

- [ ] Add more server roles (BookStack, Immich, Gitea)
- [ ] Automated backup configuration for servers
- [ ] Monitoring stack (Prometheus + Grafana)
- [ ] ARM server support (Raspberry Pi)

---

## Repository Structure (current)

```
nixos/
├── flake.nix                   # inputs, mkHost helper, nixosConfigurations
├── flake.lock
├── colmena.nix                 # server deployment targets
├── .sops.yaml                  # SOPS age key registry
├── secrets/                    # encrypted secret files
├── hosts/
│   ├── workstations/
│   │   ├── azazel/             # ThinkPad T16 Gen3
│   │   └── sukkub/             # ThinkPad P50 (test/POC)
│   ├── servers/
│   │   ├── nixos-test/
│   │   └── actual-budget/
│   ├── physical/               # altair (bare-metal homelab)
│   └── virtual/                # VMs
├── modules/
│   ├── system/                 # NixOS system-level modules
│   ├── laptop/                 # laptop hardware modules
│   ├── servers/                # server-specific modules
│   ├── services/               # shared services (ssh, tailscale, …)
│   ├── home/                   # Home Manager modules
│   └── utils/                  # yazi, nixvim, …
├── users/
│   ├── marcin/                 # workstation user (see Phase 4)
│   └── nixadm/                 # server admin user
├── packages/                   # custom Nix packages
├── scripts/                    # helper shell scripts
├── fonts/                      # custom font files
└── docs/                       # supplementary documentation
```
