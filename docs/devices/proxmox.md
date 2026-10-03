# Proxmox VE (pve)

Proxmox VE 9.2.11 on 192.168.50.200, web UI https://192.168.50.200:8006.

## API token for the monitoring (2026-10-02)

Read-only user and token for the pve exporter on the monitoring server:

```sh
pveum user add prometheus@pve --comment 'Prometheus pve-exporter (read only)'
pveum acl modify / --users prometheus@pve --roles PVEAuditor
pveum user token add prometheus@pve monitoring --privsep 0
```

The token value is `pve-exporter-token` in `secrets/altair.yaml`
(`modules/servers/monitoring/pve.nix`).

## Web UI certificate

`pveproxy-ssl.pem` (Node -> System -> Certificates, "Upload Custom
Certificate") is issued by the FreeIPA CA for `pve.home.lan` and
`192.168.50.200`, valid until 2027-09-13, uploaded by hand. Nothing renews
it; the probe `pve-web` warns 14 days before it expires. The cluster
certificate `pve-ssl.pem` still lists the old address 192.168.50.109; it is
not what clients see.

## Installed by `nix run .#fleet`

node_exporter and smartctl_exporter ("monitoring apply"), the masked SSSD
responder sockets ("fix apply" sssd-sockets).
