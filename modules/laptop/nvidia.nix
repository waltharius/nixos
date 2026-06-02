# NVIDIA graphics driver configuration with PRIME support for laptops
# Configured for hybrid Intel + NVIDIA graphics on ThinkPad P50
# GPU: Quadro M2000M (Maxwell GM107 architecture)
#
# DRIVER NOTE: Maxwell-generation GPUs (GM107, GM200 family) are NOT supported
# by the current stable NVIDIA driver (595.x+). The last driver branch with
# official Maxwell support is 470.xx. Using nvidiaPackages.legacy_470 here.
# See: https://www.nvidia.com/en-us/drivers/unix/legacy-gpu/
{
  config,
  lib,
  pkgs,
  ...
}: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # legacy_470 is required for Maxwell architecture (Quadro M2000M / GM107).
    # Do NOT change to "stable" or "beta" — those drivers will ignore this GPU.
    package = config.boot.kernelPackages.nvidiaPackages.legacy_470;

    # Required for Wayland compositors (niri, sway, hyprland, …)
    modesetting.enable = true;

    # Basic power management — safe for Maxwell.
    powerManagement.enable = true;

    # Fine-grained power management (Turing+ only, NOT supported on Maxwell).
    # Keep this false — enabling it on M2000M will cause boot issues.
    powerManagement.finegrained = false;

    # Open-source kernel module is NOT available for Maxwell.
    open = false;

    nvidiaSettings = true;

    # PRIME Sync: Intel manages the display, NVIDIA renders everything.
    # Bus IDs verified via lspci on ThinkPad P50:
    #   00:02.0 Intel HD Graphics 530  → PCI:0:2:0
    #   01:00.0 Quadro M2000M          → PCI:1:0:0
    # If you move this config to a different machine, verify with:
    #   lspci | grep -E "VGA|3D"
    prime = {
      sync.enable = true;
      intelBusId  = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Prevent TLP from fighting with the NVIDIA driver over GPU power management.
  services.tlp.settings = {
    RUNTIME_PM_DRIVER_BLACKLIST = "nvidia nouveau";
  };

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
  ];
}
