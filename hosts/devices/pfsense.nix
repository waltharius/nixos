# hosts/devices/pfsense.nix - fields are described in hosts/README.md
{
  description = "pfSense router (being replaced by OPNsense)";
  lan.ip = "192.168.50.1";
  ssh.pfsense.user = "root";
  category = "network";
  baremetal = true;
  monitoring.ping = true;
}
