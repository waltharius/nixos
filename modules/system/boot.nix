# Boot configuration for UEFI systems with systemd-boot
{pkgs, ...}: {
  boot.loader = {
    systemd-boot = {
      enable = true;
      consoleMode = "0";
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
    timeout = 5;

    # Limit number of generations in boot menu
  };

  # Enable kernel modules for common hardware
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "sd_mod"];

  # Silent boot
  boot.kernelParams = ["quiet" "splash" "video=efifb:3840x2160"];

  # Latest stable kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
