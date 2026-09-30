# users/marcin/home/fonts.nix
#
# Font configuration for marcin. Nerd Fonts are installed system-wide on
# every workstation (modules/system/fonts.nix).
# Enables fontconfig so that fonts installed via home.packages are
# discovered by applications, and symlinks the custom font collection
# from the nixos repo into the standard XDG font directory.
{
  config,
  pkgs,
  ...
}: let
  nixos-fonts = "${config.home.homeDirectory}/nixos/fonts";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
in {
  fonts.fontconfig.enable = true;

  home.packages = [pkgs.google-fonts];

  home.file.".local/share/fonts/custom" = {
    source = create_symlink nixos-fonts;
    recursive = true;
  };
}
