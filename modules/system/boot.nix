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

  # Silent boot. A panel-specific framebuffer resolution (video=efifb:...)
  # belongs to the host's custom.nix, not here.
  boot.kernelParams = ["quiet" "splash"];

  # Latest stable kernel
  #  boot.kernelPackages = pkgs.linuxPackages_6_19;
}
