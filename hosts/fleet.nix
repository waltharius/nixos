# hosts/fleet.nix
#
# Settings that apply to the whole fleet rather than to one machine.
# Machines are declared one per file in hosts/machines/ (see
# hosts/README.md); lib/inventory.nix loads and validates both.
{
  network.lan = {
    # First three octets of the home LAN.
    prefix = "192.168.50";
    # Dynamic DHCP pool of the router. Static addresses must stay outside it.
    dhcpPool = {
      first = 165;
      last = 199;
    };
  };
}
