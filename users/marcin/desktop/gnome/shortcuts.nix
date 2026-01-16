# users/marcin/desktop/gnome/shortcuts.nix
# Marcin's GNOME keyboard shortcuts
#
# NOTE:
# DEPENDENCY: This file requires run-or-raise extension
# defined in extensions.nix
{
  config,
  pkgs,
  lib,
  ...
}: let
  # Check if run-or-raise is installed
  hasRunOrRaise =
    lib.any
    (ext: ext.pname or "" == "gnome-shell-extension-run-or-raise")
    config.programs.gnome-extensions.extensionPackages;
in {
  # Only create run-or-raise config if extension is installed
  xdg.configFile."run-or-raise/shortcuts.conf" = lib.mkIf hasRunOrRaise {
    text = ''
      <Control><Alt>e,${pkgs.emacs}/bin/emacs,emacs
      <Super>f,${pkgs.brave}/bin/brave,,
      <Super>e,nautilus,org.gnome.Nautilus
      <Super>t,ptyxis,org.gnome.Ptyxis
      <Control>p,${pkgs.signal-desktop}/bin/signal-desktop,signal
    '';
  };
}
