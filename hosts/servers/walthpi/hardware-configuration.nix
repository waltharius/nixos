# hosts/servers/walthpi/hardware-configuration.nix
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  boot = {
    initrd.availableKernelModules = ["xhci_pci" "usbhid" "usb_storage"];
    initrd.kernelModules = [];
    kernelModules = [];
    extraModulePackages = [];

    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

  # Root filesystem on SD card (ext4 for reliability)
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = ["noatime" "nodiratime"];
  };

  # USB HDD with BTRFS - Single mount point
  # Subvolumes (calibre, docker, backups) appear as directories
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/ff1f8625-7f7a-42c4-af1c-5298f03e8d7a";
    fsType = "btrfs";
    options = [
      "noatime"
      "compress=zstd:3"
      "space_cache=v2"
    ];
  };

  # Swap file on USB HDD (not SD card!)
  swapDevices = [
    {
      device = "/mnt/storage/swapfile";
      size = 4096; # 4GB
    }
  ];

  # ARM-specific
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  hardware.enableRedistributableFirmware = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}
