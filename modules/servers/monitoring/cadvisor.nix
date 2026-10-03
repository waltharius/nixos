# modules/servers/monitoring/cadvisor.nix
#
# cAdvisor for the Podman containers of the monitoring server (altair: Open
# WebUI, SearXNG, zotero2readwise), scraped by the job `cadvisor` in
# prometheus.nix together with the Docker hosts (devices with
# `monitoring.cadvisor = true`). One exporter for Docker and Podman gives
# one set of metrics (container_*) and one dashboard; nixpkgs has no NixOS
# module for prometheus-podman-exporter.
#
# cAdvisor reads rootful Podman through /run/podman/podman.sock (the
# podman.socket unit of virtualisation.podman; its default -podman flag).
# -docker_only: only containers (and the root cgroup), not every systemd
# service as a "container"; the Podman handler still reports Podman
# containers. Loopback only, port 8099: 8080 belongs to SearXNG.
{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.virtualisation.podman.enable {
    services.cadvisor = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 8099;
      extraOptions = [
        "-docker_only=true"
        # cAdvisor's default housekeeping is every second; the same values
        # as the Ansible role uses on the Docker hosts.
        "-housekeeping_interval=10s"
        "-max_housekeeping_interval=15s"
      ];
    };
  };
}
