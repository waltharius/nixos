# Activating niri on a Single Host

This document explains the architecture used in this repository to keep
`niri` configuration isolated to a single host, and shows the exact steps
to enable or disable it.

---

## Background — Why the Module is Isolated

The repository uses a shared `mkHost` factory in `flake.nix` that builds
every workstation from a common set of NixOS modules. Loading
`niri-flake.nixosModules.niri` inside `mkHost` would inject the niri NixOS
session and its Home Manager module into **all** hosts — including machines
that will never run niri. This creates two concrete problems:

1. **Unnecessary evaluation overhead** on hosts that do not use niri.
2. **Circular-looking dependencies**: `users/marcin/home.nix` would have to
   import `modules/home/desktop/niri.nix` statically, which references
   `programs.niri.settings` — an option that only exists when
   `niri-flake.homeModules.niri` is loaded. On a host without that flake
   module the build fails.

The solution is to make `modules/system/niri.nix` **self-contained**: it
imports `niri-flake.nixosModules.niri` itself, so a host profile only needs
one line to get everything. No global side-effects, no cross-file
dependencies.

---

## Repository Structure

```
modules/
  system/
    niri.nix              ← NixOS module (self-contained, not imported globally)
  home/
    desktop/
      niri.nix            ← Home Manager module (waybar, mako, rofi, bindings…)

hosts/workstations/
  sukkub/
    profile.nix           ← where niri would be imported for sukkub
  azazel/
    profile.nix           ← untouched; knows nothing about niri

users/marcin/
  home.nix                ← does NOT import niri.nix; only gnome.nix is global
  profiles/
    sukkub.nix            ← marcin.desktop = "gnome"  (niri disabled for now)
    azazel.nix            ← marcin.desktop = "gnome"
```

### What each niri module owns

| Module | Layer | Responsibility |
|--------|-------|----------------|
| `modules/system/niri.nix` | NixOS | Registers niri as a Wayland session, configures greetd + regreet + cage, sets `WLR_DRM_DEVICES`, XDG portals, polkit, session environment variables |
| `modules/home/desktop/niri.nix` | Home Manager | `programs.niri.settings` (keybindings, layout, outputs), waybar, mako, rofi, swaylock, swayidle, polkit agent user service |

The two modules are intentionally separate because they operate at different
evaluation layers (NixOS vs. Home Manager) and because some future host
might need the NixOS session registration without the exact same HM
configuration.

---

## How to Enable niri on a Host

Two files need to change. The example below uses `sukkub`.

### Step 1 — Host NixOS profile (`hosts/workstations/sukkub/profile.nix`)

Add the two imports. The `inputs` argument is already available in every
host profile via `specialArgs`.

```nix
# hosts/workstations/sukkub/profile.nix
{ inputs, ... }: {
  imports = [
    ../../../modules/system/niri.nix          # NixOS: session, greetd, system deps
  ];

  # Inject the HM niri module only for this host's marcin user.
  # This is the correct way to add a per-host HM module without touching
  # users/marcin/home.nix (which is shared across all hosts).
  home-manager.users.marcin.imports = [
    ../../../modules/home/desktop/niri.nix    # HM: bindings, waybar, mako, rofi…
  ];
}
```

> **Why `home-manager.users.marcin.imports` and not a static import in
> `home.nix`?**
> `users/marcin/home.nix` is evaluated for every host. If it imported
> `niri.nix` statically, `programs.niri.settings` (provided by
> `niri-flake.homeModules.niri`) would need to exist on every host.
> `home-manager.users.marcin.imports` in a NixOS module is evaluated only
> for the host that loads that module, so the option is guaranteed to exist
> by the time the HM module runs (because `modules/system/niri.nix` has
> already imported `niri-flake.nixosModules.niri`, which auto-injects
> `homeModules.niri` for all HM users on that host).

### Step 2 — User HM profile (`users/marcin/profiles/sukkub.nix`)

Add `"niri"` to `marcin.desktop` so the HM niri module activates its
`lib.mkIf niri { … }` block.

```nix
# users/marcin/profiles/sukkub.nix
{ ... }: {
  marcin.desktop = [ "gnome" "niri" ];   # both sessions available at GDM
}
```

Both `"gnome"` and `"niri"` can coexist: GNOME registers its session via
GDM and niri registers its session via greetd. At login you choose which
session to start. Remove `"gnome"` only once you are comfortable working
exclusively in niri.

---

## How to Disable niri on a Host

Reverse the two steps above:

1. In `hosts/workstations/<hostname>/profile.nix`, remove the
   `modules/system/niri.nix` import and the
   `home-manager.users.marcin.imports` entry.
2. In `users/marcin/profiles/<hostname>.nix`, change `marcin.desktop` back
   to `"gnome"` (or whichever DE you want).

No other file needs to change. `azazel` and any future host are completely
unaffected.

---

## Adding niri to a Brand-New Host

Same two steps. The only additional requirement is that `inputs` is
available in `specialArgs` for the new host — which it already is for every
host built by `mkHost` in `flake.nix`.

---

## Important Constraints

- **Never import both `modules/system/niri.nix` and `modules/system/desktop/gnome.nix`
  on the same host** unless you understand that they configure different
  display managers (greetd vs. GDM). An `assertions` check in
  `modules/system/niri.nix` will fail the build if GDM is already enabled
  when niri.nix loads.
- **Do not add `niri-flake.homeModules.niri` to `sharedModules` in
  `flake.nix`.** It is already auto-injected by
  `niri-flake.nixosModules.niri` (which is imported by
  `modules/system/niri.nix`). A duplicate declaration causes a
  conflicting-option build error.
- **`modules/home/desktop/niri.nix` must not appear in `users/marcin/home.nix`.**
  That file is evaluated globally; loading an option that depends on a
  host-specific flake module there would break every host that does not use
  niri.

---

## ThinkPad P50 — Hardware Notes

`modules/system/niri.nix` contains sukkub-specific hardware tuning that
should be reviewed before enabling niri on a different machine:

| Setting | Value | Reason |
|---------|-------|--------|
| `WLR_DRM_DEVICES` | `/dev/dri/card1` | Intel iGPU (HD 530) must be used; `card0` is the NVIDIA Quadro which requires the legacy 470 driver and does not support modern Wayland DRM |
| `LIBVA_DRIVER_NAME` | `iHD` | Intel Media Driver for VA-API hardware decode |
| `outputs."eDP-1".scale` | `2.0` | 4K panel at 200 % |

On a machine without an NVIDIA dGPU (e.g. `azazel`) the `WLR_DRM_DEVICES`
override is unnecessary and `card0` will typically be the correct device.
Adjust or remove these values in `modules/system/niri.nix` for the target
machine before rebuilding.
