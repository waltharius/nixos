# hosts/workstations/@HOST@/configuration.nix
#
# @HOST@ - @DESCRIPTION@
#
# Only what is unique to this machine: host name, state version, disk
# layout and machine quirks. Hardware modules go into custom.nix; accounts
# and programs come from hosts/machines/@HOST@.nix.
{
  hostname,
  inputs,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  networking.hostName = hostname;

  nix.settings.experimental-features = ["nix-command" "flakes"];

  # DO NOT change stateVersion after the initial installation.
  system.stateVersion = "@STATE_VERSION@";
}
