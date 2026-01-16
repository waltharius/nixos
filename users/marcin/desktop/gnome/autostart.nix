# users/marcin/desktop/gnome/autostart.nix
# Marcin's GNOME autostart applications
#
# DEPENDENCY: Only creates autostart entries for installed packages
# Packages are defined in users/marcin/apps.nix

{
  config,
  pkgs,
  lib,
  ...
}: let
  # Check if packages are installed in home.packages
  hasSignal = lib.any (pkg: pkg.pname or "" == "signal-desktop") config.home.packages;
  hasPtyxis = lib.any (pkg: pkg.pname or "" == "ptyxis") config.home.packages;
  hasSolaar = lib.any (pkg: pkg.pname or "" == "solaar") config.home.packages;
in {
  # Signal autostart (only if installed in apps.nix)
  xdg.configFile."autostart/signal-desktop.desktop" = lib.mkIf hasSignal {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Signal
      Exec=${pkgs.signal-desktop}/bin/signal-desktop
      Terminal=false
    '';
  };

  # Ptyxis autostart (only if installed)
  xdg.configFile."autostart/ptyxis.desktop" = lib.mkIf hasPtyxis {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Ptyxis
      Exec=${pkgs.ptyxis}/bin/ptyxis
      Terminal=false
    '';
  };

  # Solaar autostart (only if installed)
  xdg.configFile."autostart/solaar.desktop" = lib.mkIf hasSolaar {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Solaar
      Exec=solaar --window=hide
      Icon=solaar
      StartupNotify=false
      NoDisplay=true
    '';
  };
}
