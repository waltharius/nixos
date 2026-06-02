# NVIDIA graphics driver configuration with PRIME support for laptops
# Configured for hybrid Intel + NVIDIA graphics on ThinkPad P50
# GPU: Quadro M2000M (Maxwell GM107 architecture)
#
# DRIVER NOTE: Maxwell-generation GPUs (GM107, GM200 family) are NOT supported
# by the current stable NVIDIA driver (595.x+). The last driver branch with
# official Maxwell support is 470.xx. Using nvidiaPackages.legacy_470 here.
# See: https://www.nvidia.com/en-us/drivers/unix/legacy-gpu/
#
# PRIME MODE: offload (not sync)
# --------------------------------
# PRIME sync.enable=true makes Intel own the display and NVIDIA render
# everything. GNOME has special integration that handles this transparently.
# Non-GNOME Wayland compositors (niri, sway, hyprland) do NOT have this
# integration — they crash or produce a black screen when sync is active,
# because they cannot negotiate GBM buffer handoff correctly with the
# legacy_470 driver on Maxwell.
#
# PRIME offload is the correct mode for mixed-DE setups: Intel drives the
# display natively (faster resume, lower power), and NVIDIA is activated
# explicitly per-application with `nvidia-offload <cmd>` or the
# __NV_PRIME_RENDER_OFFLOAD env var. This works identically under GNOME
# and niri.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Wrapper script that sets the three env vars needed to offload a single
  # application to the NVIDIA GPU. Usage: nvidia-offload <command> [args…]
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __EGL_VENDOR_LIBRARY_FILENAMES=${config.hardware.nvidia.package}/share/glvnd/egl_vendor.d/10_nvidia.json
    exec "$@"
  '';
in {
  hardware.graphics = {
    enable      = true;
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

    # PRIME Offload: Intel drives the display; NVIDIA renders only when
    # explicitly requested via the nvidia-offload wrapper or the env vars.
    # Bus IDs verified via lspci on ThinkPad P50:
    #   00:02.0 Intel HD Graphics 530  → PCI:0:2:0
    #   01:00.0 Quadro M2000M          → PCI:1:0:0
    # If you move this config to a different machine, verify with:
    #   lspci | grep -E "VGA|3D"
    prime = {
      offload.enable           = true;
      offload.enableOffloadCmd = false;  # we ship our own wrapper below
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
    nvidia-offload
  ];
}
