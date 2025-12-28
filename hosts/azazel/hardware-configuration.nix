# Hardware configuration for Azazel
# This file will be generated during installation with:
#   nixos-generate-config --root /mnt
#
# IMPORTANT: Replace this placeholder with actual hardware-configuration.nix
# generated during installation!
#
# This placeholder exists only to allow flake evaluation before installation.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  # PLACEHOLDER - will be replaced during installation
  boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod"];
  boot.kernelModules = ["kvm-intel"];

  # Placeholder filesystem configuration
  # REPLACE with actual configuration after running nixos-generate-config
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/REPLACE-ME";
    fsType = "btrfs";
    options = ["subvol=@root" "compress=zstd:3" "noatime"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/REPLACE-ME";
    fsType = "btrfs";
    options = ["subvol=@home" "compress=zstd:3" "noatime"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/REPLACE-ME";
    fsType = "btrfs";
    options = ["subvol=@nix" "noatime"]; # No compression for /nix
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/REPLACE-ME";
    fsType = "vfat";
    options = ["defaults" "noatime"];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
