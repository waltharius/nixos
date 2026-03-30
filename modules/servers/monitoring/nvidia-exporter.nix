# modules/servers/monitoring/nvidia-exporter.nix
#
# NVIDIA GPU exporter for Prometheus.
# Uses prometheus-nvidia-gpu-exporter (nvidia-smi based).
# Binds loopback only. Prometheus scrapes 127.0.0.1:9835.
#
# Prerequisites: nvidia.nix must be imported (provides nvidia-smi in PATH).
# Both RTX 3090s (GPU 0 and GPU 1) are exported automatically.
{
  config,
  pkgs,
  ...
}: {
  services.prometheus.exporters.nvidia-gpu = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9835;
  };

  # nvidia-smi must be reachable by the exporter process
  # The exporter runs as its own user — give it access via PATH
  systemd.services.prometheus-nvidia-gpu-exporter.environment = {
    PATH = "${config.hardware.nvidia.package.bin}/bin:${pkgs.coreutils}/bin";
  };

  # Firewall: no extra rule needed — loopback only
}
