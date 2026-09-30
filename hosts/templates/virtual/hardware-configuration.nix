# PLACEHOLDER written by `nix run .#new-host`.
#
# It lets @HOST@ evaluate before the machine is installed. The installation
# (refactor stage 3, nixos-anywhere) replaces this file with the hardware
# scan of the real machine. Do not install or deploy @HOST@ while this
# placeholder is here: the initrd would lack the machine's drivers.
{lib, ...}: {
  nixpkgs.hostPlatform = lib.mkDefault "@SYSTEM@";
}
