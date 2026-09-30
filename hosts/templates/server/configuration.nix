# hosts/physical/@HOST@/configuration.nix
#
# @HOST@ - @DESCRIPTION@
#
# Bare-metal server administered through nixadm. The static address and
# its interface come from hosts/machines/@HOST@.nix (lan.ip,
# lan.interface; see modules/servers/base-baremetal.nix).
#
# base-baremetal.nix also enables SSH in the initrd for the LUKS
# passphrase (modules/servers/encryption/initrd-ssh.nix), which needs its
# own host key on the machine; see that module before installing.
{hostname, ...}: {
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../../modules/servers/security/hardening.nix
    ../../../modules/servers/base-baremetal.nix
  ];

  networking.hostName = hostname;

  # DO NOT change stateVersion after the initial installation.
  system.stateVersion = "@STATE_VERSION@";
}
