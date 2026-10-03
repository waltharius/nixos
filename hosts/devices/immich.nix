# hosts/devices/immich.nix - fields are described in hosts/README.md
{
  description = "Immich (Proxmox guest)";
  lan.ip = "192.168.50.100";
  ssh.immich.user = "root";
  category = "proxmox-guest";
  monitoring = {
    ping = true;
    # node_exporter, installed with `nix run .#fleet` (monitoring apply).
    node = true;
  };
}
