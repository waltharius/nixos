# hosts/devices/pfsense.nix - fields are described in hosts/README.md
{
  description = "pfSense router (being replaced by OPNsense)";
  lan.ip = "192.168.50.1";
  ssh.pfsense.user = "root";
  category = "network";
  baremetal = true;
  monitoring = {
    ping = true;
    # node_exporter from the pfSense package manager (System -> Package
    # Manager), listening on LAN:9100; not installed by `nix run .#fleet`.
    nodeExternal = true;
    # APC Back-UPS 850 on USB, NUT package, upsd on port 3493 (Services ->
    # UPS); read by the nut exporter on the monitoring server.
    ups = "apcups";
  };
}
