# hosts/devices/cloudflare-ddns.nix - fields are described in hosts/README.md
{
  description = "Cloudflare DDNS (Proxmox guest)";
  lan.ip = "192.168.50.10";
  ssh.cloudflare-ddns.user = "root";
  category = "proxmox-guest";
  monitoring = {
    ping = true;
    # node_exporter, installed with `nix run .#fleet` (monitoring apply).
    node = true;
  };
}
