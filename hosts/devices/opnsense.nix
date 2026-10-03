# hosts/devices/opnsense.nix - fields are described in hosts/README.md
#
# Not monitored: OPNsense broke during an update and waits for the router
# swap stage (BACKLOG.md). The entry stays so the address remains reserved.
{
  description = "OPNsense router (Dell Wyse 5070, broken, see BACKLOG.md)";
  lan.ip = "192.168.50.149";
  category = "network";
  baremetal = true;
}
