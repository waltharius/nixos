# hosts/devices/apache.nix - fields are described in hosts/README.md
{
  description = "Apache (Proxmox guest)";
  lan.ip = "192.168.50.151";
  ssh.apache.user = "root";
  category = "proxmox-guest";
  monitoring = {
    ping = true;
    # node_exporter, installed with `nix run .#fleet` (monitoring apply).
    node = true;
  };
}
