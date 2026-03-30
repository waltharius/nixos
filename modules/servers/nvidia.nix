# modules/servers/nvidia.nix
{
  config,
  pkgs,
  ...
}: {
  # Load nvidia kernel module
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false; # proprietary — required for CUDA on 3090
    nvidiaSettings = false; # headless server, no GUI settings app
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
  };

  hardware.nvidia-container-toolkit.enable = true; # for future Incus GPU passthrough

  # Kernel modules
  boot.kernelModules = ["nvidia" "nvidia_uvm" "nvidia_drm"];
  boot.extraModprobeConfig = ''
    options nvidia NVreg_PreserveVideoMemoryAllocations=1
  '';

  # Enable CUDA
  nixpkgs.config.cudaSupport = true;

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia # GPU monitor
    cudatoolkit
  ];
}
