# hosts/workstations/azazel/configuration.nix
#
# Azazel — ThinkPad T16 Gen3 (primary production host).
# Hardware: AMD Ryzen, 128 GB RAM, NVMe, no discrete GPU.
#
# This file contains ONLY what is unique to this physical machine:
# hostname, state version and hardware-specific boot settings. Hardware
# modules and host features are imported in custom.nix; accounts and
# programs come from hosts/machines/<host>.nix.
{hostname, ...}: {
  networking.hostName = hostname;

  # Firmware update support via LVFS.
  services.fwupd.enable = true;

  # systemd in initrd is required for the automatic hibernation offset
  # calculation and EFI variable setup used by hibernate.nix.
  boot.initrd.systemd.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Syncthing: group `syncthing` (hosts/machines/azazel.nix).

  # DO NOT change stateVersion after the initial installation.
  # It controls the format of stateful data (databases, dotfiles) and
  # changing it will not upgrade anything — it only breaks assumptions.
  system.stateVersion = "25.11";
}
