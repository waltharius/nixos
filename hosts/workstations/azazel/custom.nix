# hosts/workstations/azazel/custom.nix
#
# What azazel (ThinkPad T16 Gen3) has that other workstations do not:
# hardware support, disk layout and host-level features.
#
# Everything every workstation gets (boot, networking, audio, printing,
# Flatpak, fonts, ...) comes from the class in lib/classes.nix; programs
# come from the groups of the host's users in hosts/machines/<host>.nix.
{...}: {
  imports = [
    # --- disk configuration ---
    ./btrfs-subvolumes.nix
    ../../../modules/system/btrfs.nix

    # --- peripherals ---
    ../../../modules/system/hardware/keyboard-qmk.nix
    ../../../modules/services/solaar.nix

    # --- power management ---
    ./tlp.nix
    ./hibernate.nix

    # --- laptop hardware ---
    ../../../modules/laptop/thunderbolt.nix
    ../../../modules/laptop/suspend-fix.nix
    ../../../modules/laptop/acpi-fix.nix
    ../../../modules/laptop/fingerprint.nix

    # --- host features ---
    ../../../modules/system/auto-upgrade.nix
    ../../../modules/services/podman.nix
  ];

  # Enable SOPS secrets management (age key at /var/lib/sops-nix/key.txt).
  # Must be set per-host because the secrets module is opt-in.
  services.secrets.enable = true;

  # Framebuffer resolution of azazel's 4K panel for the console and
  # Plymouth (was in modules/system/boot.nix for every workstation).
  boot.kernelParams = ["video=efifb:3840x2160"];
}
