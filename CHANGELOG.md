# Changelog

All notable changes to this repository are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
The repository has no releases, so entries are grouped by date and refactor
stage instead of version numbers. Every entry ends with **Lessons learned**:
what went wrong, what was surprising, and what should be done differently
next time. Changes that were reverted stay in the log together with the
reason for reverting them.

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
