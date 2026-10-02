# hosts/devices/pve.nix - fields are described in hosts/README.md
{
  description = "Proxmox VE host";
  lan.ip = "192.168.50.200";
  ssh.pve.user = "root";
  monitoring = {
    ping = true;
    # Read through the Proxmox API by the pve exporter on the monitoring
    # server (modules/servers/monitoring/pve.nix): the host itself and
    # every VM, container and storage. Token prometheus@pve!monitoring.
    pve = true;
  };
}
