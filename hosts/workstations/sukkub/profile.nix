# hosts/workstations/sukkub/profile.nix
#
# Module list for sukkub (ThinkPad P50 — test/POC host).
#
# This file is the single authoritative source of which optional modules
# are active on this host. Adding or removing a module here is the only
# change required to enable or disable a feature — no other file needs
# to be touched.
#
# Modules that are common to every workstation (boot, networking, locale,
# secrets, sops, home-manager) are loaded by mkHost in flake.nix and are
# therefore NOT listed here to avoid duplication.
{ ... }: {
  imports = [
    # --- desktop environments ---
    ../../../modules/system/desktop/gnome.nix
    ../../../modules/system/niri.nix        # niri Wayland session

    # --- DE-agnostic hardware services ---
    ../../../modules/system/hardware/audio.nix
    ../../../modules/system/hardware/printing.nix
    ../../../modules/system/hardware/flatpak.nix

    # --- power management (host-specific) ---
    ./tlp.nix
    ./hibernate.nix

    # --- laptop hardware ---
    ../../../modules/laptop/thunderbolt.nix
    ../../../modules/laptop/acpi-suspend.nix
    ../../../modules/laptop/nvidia.nix

    # --- optional system features ---
    ../../../modules/system/gaming.nix
    ../../../modules/system/certificates.nix
    ../../../modules/system/brave.nix
    ../../../modules/system/plymouth.nix
    ../../../modules/system/sudo.nix

    # --- services ---
    ../../../modules/services/solaar.nix
  ];

  services.secrets.enable = true;
}
