# hosts/workstations/sukkub/custom.nix
#
# What sukkub (ThinkPad P50, test/POC host) has that other workstations do
# not: hardware support and host-level features.
#
# Everything every workstation gets (boot, networking, audio, printing,
# Flatpak, fonts, ...) comes from the class in lib/classes.nix; programs
# come from the groups of the host's users in hosts/inventory.nix.
{...}: {
  imports = [
    # --- peripherals ---
    ../../../modules/system/hardware/keyboard-qmk.nix
    ../../../modules/services/solaar.nix

    # --- power management ---
    ./tlp.nix
    ./hibernate.nix

    # --- laptop hardware ---
    ../../../modules/laptop/thunderbolt.nix
    ../../../modules/laptop/acpi-suspend.nix
    ../../../modules/laptop/nvidia.nix
  ];

  services.secrets.enable = true;
}
