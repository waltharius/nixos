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
#
# Podman containers need `autoRemoveOnStop = false`: cAdvisor up to 0.56
# (nixpkgs 26.05 has 0.56.2) looks a container up only in
# storage/overlay-containers/containers.json, but `podman run --rm` (the
# oci-containers default) stores it in volatile-containers.json, so cAdvisor
# fails with 'containers.json: no such file or directory' and reports no
# Podman container. cAdvisor 0.60 reads both files. Without `--rm` nothing
# else changes: the oci-containers unit removes the container in postStop
# and before every start anyway. A warning below lists containers that
# still use `--rm`; it disappears by itself once nixpkgs has cAdvisor 0.60.
# -docker_only: only containers (and the root cgroup), not every systemd
# service as a "container"; the Podman handler still reports Podman
# containers. Loopback only, port 8099: 8080 belongs to SearXNG.
{
  config,
  lib,
  pkgs,
  ...
}: let
  volatile =
    lib.attrNames (lib.filterAttrs (_: c: c.autoRemoveOnStop)
      config.virtualisation.oci-containers.containers);
in {
  config = lib.mkIf config.virtualisation.podman.enable {
    warnings =
      lib.optional (volatile != [] && lib.versionOlder pkgs.cadvisor.version "0.60")
      "cAdvisor ${pkgs.cadvisor.version} cannot see Podman containers started with --rm: set `autoRemoveOnStop = false` on ${lib.concatStringsSep ", " volatile} (modules/servers/monitoring/cadvisor.nix).";

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
