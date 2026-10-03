# hosts/devices/syncthing-server.nix - fields are described in hosts/README.md
{
  description = "Syncthing (Proxmox guest)";
  lan.ip = "192.168.50.95";
  ssh.syncthing-server.user = "root";
  category = "proxmox-guest";
  monitoring = {
    ping = true;
    # node_exporter, installed with `nix run .#fleet` (monitoring apply).
    node = true;
  };
}
