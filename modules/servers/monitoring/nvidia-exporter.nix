# modules/servers/monitoring/nvidia-exporter.nix
#
# NVIDIA GPU exporter for Prometheus.
# Uses prometheus-nvidia-gpu-exporter (nvidia-smi based).
# Binds loopback only. Prometheus scrapes 127.0.0.1:9835.
#
# Prerequisites: nvidia.nix must be imported (provides nvidia-smi via
# hardware.nvidia.package). The NixOS exporter module locates nvidia-smi
# automatically through the nvidiaPackage option — no PATH override needed.
# Both RTX 3090s (GPU 0 and GPU 1) are exported automatically.
{config, ...}: {
  services.prometheus.exporters.nvidia-gpu = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9835;
    # Point the exporter at the correct nvidia-smi binary.
    # The module prepends this package's bin/ to the service PATH internally,
    # avoiding any conflict with the systemd default PATH.
    nvidiaPackage = config.hardware.nvidia.package;
  };

  # Firewall: no extra rule needed — loopback only
}
