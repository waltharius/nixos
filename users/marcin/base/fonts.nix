# users/marcin/base/fonts.nix
#
# Font configuration for marcin.
# Enables fontconfig so that fonts installed via home.packages are
# discovered by applications, and symlinks the custom font collection
# from the nixos repo into the standard XDG font directory.
{ config, ... }: let
  nixos-fonts    = "${config.home.homeDirectory}/nixos/fonts";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
in {
  fonts.fontconfig.enable = true;

  home.file.".local/share/fonts/custom" = {
    source    = create_symlink nixos-fonts;
    recursive = true;
  };
}
