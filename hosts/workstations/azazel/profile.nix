# hosts/workstations/azazel/profile.nix
#
# Module list for azazel (ThinkPad T16 Gen3).
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
    # --- desktop environment ---
    ../../../modules/system/desktop/gnome.nix

    # --- DE-agnostic hardware services ---
    ../../../modules/system/hardware/audio.nix
    ../../../modules/system/hardware/printing.nix
    ../../../modules/system/hardware/flatpak.nix

    # --- power management (host-specific) ---
    ./tlp.nix
    ./hibernate.nix

    # --- laptop hardware ---
    ../../../modules/laptop/thunderbolt.nix
    ../../../modules/laptop/suspend-fix.nix
    ../../../modules/laptop/acpi-fix.nix
    ../../../modules/laptop/fingerprint.nix

    # --- optional system features ---
    ../../../modules/system/gaming.nix
    ../../../modules/system/auto-upgrade.nix
    ../../../modules/system/certificates.nix
    ../../../modules/system/brave.nix
    ../../../modules/system/plymouth.nix
    ../../../modules/system/sudo.nix

    # --- services ---
    ../../../modules/services/solaar.nix
    ../../../modules/services/tailscale.nix
    ../../../modules/services/podman.nix
  ];

  # Enable SOPS secrets management (age key at /var/lib/sops-nix/key.txt).
  # Must be set per-host because the secrets module is opt-in.
  services.secrets.enable = true;
}
