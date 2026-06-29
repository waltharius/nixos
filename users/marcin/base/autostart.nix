# users/marcin/base/autostart.nix
#
# XDG autostart entries for marcin.
# These .desktop files are placed in ~/.config/autostart and are
# executed by the desktop session on first login, regardless of which
# desktop environment is active (GNOME, niri, Sway, …).
#
# NOTE: Do NOT interpolate pkgs.* store paths here. Doing so forces Nix
# to evaluate the full build closure of each package at rebuild time,
# which fails if any transitive build dependency is marked insecure.
# Bare command names resolve correctly via $PATH in a NixOS session.
{...}: {
  xdg.configFile = {
    "autostart/signal-desktop.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Signal
      Exec=signal-desktop
      Terminal=false
    '';

    "autostart/ptyxis.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Ptyxis
      Exec=ptyxis
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
