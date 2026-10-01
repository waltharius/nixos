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

  # Tailscale (lib/tailscale.nix, docs/REMOTE-ACCESS.md). null logs in to
  # Tailscale's own control server; an https:// URL points every machine
  # that is not `join = "shared"` to another one (Headscale, later). Changing
  # it does not move machines that are already logged in: run
  # `tailscale-join` on each of them.
  tailscale.loginServer = null;

  # Age keys that can decrypt every secret: the sops CLI of the
  # administrator (~/.config/sops/age/keys.txt on azazel). Host keys are in
  # the machine files. See secrets/README.md.
  sops.admins = {
    admin = "age1t73dnh9pj2qsz3rfqgq54t2pyxh8ew6w8xsta7pfwmmxmsjswgrshue8gx";
  };
}
