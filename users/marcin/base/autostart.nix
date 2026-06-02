# users/marcin/base/autostart.nix
#
# XDG autostart entries for marcin.
# These .desktop files are placed in ~/.config/autostart and are
# executed by the desktop session on first login, regardless of which
# desktop environment is active (GNOME, niri, Sway, …).
#
# Each entry uses the Nix store path of the executable so the correct
# binary is launched even after a garbage collection.
{ pkgs, ... }: {
  xdg.configFile = {
    "autostart/signal-desktop.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Signal
      Exec=${pkgs.signal-desktop}/bin/signal-desktop
      Terminal=false
    '';

    "autostart/ptyxis.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Ptyxis
      Exec=${pkgs.ptyxis}/bin/ptyxis
    '';

    "autostart/solaar.desktop".text = ''
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
