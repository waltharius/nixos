# hosts/devices/ipa.nix - fields are described in hosts/README.md
{
  description = "FreeIPA (Proxmox guest)";
  lan.ip = "192.168.50.250";
  ssh.ipa.user = "root";
  category = "proxmox-guest";
  monitoring = {
    ping = true;
    # node_exporter, installed with `nix run .#fleet` (monitoring apply).
    node = true;
  };
}
