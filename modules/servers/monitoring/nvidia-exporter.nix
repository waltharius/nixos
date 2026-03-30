# modules/servers/monitoring/nvidia-exporter.nix
#
# NVIDIA GPU exporter for Prometheus.
# Uses prometheus-nvidia-gpu-exporter (nvidia-smi based).
# Binds loopback only. Prometheus scrapes 127.0.0.1:9835.
#
# The exporter calls nvidia-smi at runtime. We add the nvidia bin package
# to the service's `path` (distinct from `environment.PATH`) so it
# doesn't conflict with the systemd default PATH definition.
{config, ...}: {
  services.prometheus.exporters.nvidia-gpu = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9835;
  };

  # `path` appends packages to the service's PATH without
  # conflicting with systemd.nix's environment.PATH definition.
  systemd.services.prometheus-nvidia-gpu-exporter.path = [
    config.hardware.nvidia.package.bin
  ];

  # Firewall: no extra rule needed — loopback only
}
