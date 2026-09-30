# hosts/virtual/@HOST@/configuration.nix
#
# @HOST@ - @DESCRIPTION@
#
# LXC container administered through nixadm (modules/servers/base-lxc.nix).
{host, ...}: {
  imports = [
    ./hardware-configuration.nix
    ../../../modules/servers/base-lxc.nix
  ];

  networking.hostName = host.name;

  # DO NOT change stateVersion after the initial installation.
  system.stateVersion = "@STATE_VERSION@";
}
