# modules/system/fonts.nix
#
# Fonts for every user of a workstation: Nerd Fonts for the icons used by
# eza, starship and yazi. Liberation (metric-compatible Arial, Times New
# Roman, Courier New) is already among the NixOS default fonts.
{pkgs, ...}: {
  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
  ];
}
