# hosts/devices/walthpi.nix - fields are described in hosts/README.md
{
  description = "Raspberry Pi";
  lan.ip = "192.168.50.47";
  ssh.walthpi.user = "walthpi";
  category = "pi";
  baremetal = true;
  monitoring = {
    ping = true;
    # node_exporter, installed with `nix run .#fleet` (monitoring apply).
    # No smartctl: the only disk is the SD card, which has no SMART.
    node = true;
  };
}
