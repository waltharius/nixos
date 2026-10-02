# modules/servers/monitoring/pve.nix
#
# prometheus-pve-exporter on the monitoring server: reads the Proxmox VE
# API of every device with `monitoring.pve = true` (hosts/devices/) and
# exposes the state of the host, its VMs, LXC containers and storage.
# Nothing is installed on Proxmox. Prometheus passes the Proxmox address as
# ?target= (job `pve` in prometheus.nix); the exporter listens on loopback.
#
# Credentials: a read-only API token, created on the Proxmox host with
#   pveum user add prometheus@pve --comment 'Prometheus pve-exporter (read only)'
#   pveum acl modify / --users prometheus@pve --roles PVEAuditor
#   pveum user token add prometheus@pve monitoring --privsep 0
# (--privsep 0: the token has the user's PVEAuditor rights). The token
# value is `pve-exporter-token` in secrets/altair.yaml; sops-nix renders
# the environment file below, which systemd reads as root. A second
# Proxmox host would need the same user and token name.
#
# TLS: pveproxy serves a certificate issued by the FreeIPA CA
# (pveproxy-ssl.pem; it covers pve.home.lan and 192.168.50.200). The
# exporter verifies it against that CA only: requests reads
# REQUESTS_CA_BUNDLE whenever verification is on. Python in nixpkgs does
# not use the system CA bundle (certifi points at nixpkgs' cacert), so the
# FreeIPA CA in security.pki would not be seen otherwise.
#
# Collectors: the exporter's defaults, including backup-info (guests that
# no backup job covers), which the NixOS module has no option for;
# replication is off (single node, no replication jobs).
{
  config,
  lib,
  ...
}: let
  targets = config.fleet.monitoring.targets.pve;
in {
  config = lib.mkIf (targets != []) {
    services.prometheus.exporters.pve = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9221;
      environmentFile = config.sops.templates."pve-exporter.env".path;
      collectors.replication = false;
    };

    systemd.services.prometheus-pve-exporter.environment.REQUESTS_CA_BUNDLE = "${../../../certs/freeipa-ca.crt}";

    sops.secrets.pve-exporter-token = {
      sopsFile = ../../../secrets/altair.yaml;
      # Key in secrets/altair.yaml: pve-exporter-token
      # Value: the token's `value` (a UUID) from `pveum user token add`
    };

    sops.templates."pve-exporter.env".content = ''
      PVE_USER=prometheus@pve
      PVE_TOKEN_NAME=monitoring
      PVE_TOKEN_VALUE=${config.sops.placeholder.pve-exporter-token}
      PVE_VERIFY_SSL=true
    '';
  };
}
