# Boot configuration for UEFI systems with systemd-boot
{
  config,
  lib,
  pkgs,
  ...
}: {
  boot.loader = {
    systemd-boot = {
      enable = true;
      consoleMode = "max";
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
    timeout = 5;

    # Limit number of generations in boot menu
  };

  # Enable kernel modules for common hardware
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "sd_mod"];

  # Silent boot
  boot.kernelParams = ["quiet" "splash"];

  # Latest stable kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
