# users/marcin/home/autostart.nix
#
# XDG autostart entries for marcin, placed in ~/.config/autostart.
# An entry is added only when the program is there: Signal and Thunderbird
# with the `comms` group, Ptyxis with `gnome`, Solaar when the host has it.
#
# NOTE: Do NOT interpolate pkgs.* store paths here. Doing so forces Nix
# to evaluate the full build closure of each package at rebuild time,
# which fails if any transitive build dependency is marked insecure.
# Bare command names resolve correctly via $PATH in a NixOS session.
{
  config,
  lib,
  osConfig,
  ...
}: let
  has = group: lib.elem group config.fleet.groups;
  hostHasSolaar = lib.any (p: (p.pname or "") == "solaar") osConfig.environment.systemPackages;
in {
  xdg.configFile =
    lib.optionalAttrs (has "comms") {
      "autostart/signal-desktop.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Signal
        Exec=signal-desktop
        Terminal=false
      '';

      "autostart/thunderbird.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Thunderbird
        Exec=thunderbird
        Icon=thunderbird
        X-GNOME-Autostart-enabled=true
      '';
    }
    // lib.optionalAttrs (has "gnome") {
      "autostart/ptyxis.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Ptyxis
        Exec=ptyxis
      '';
    }
    // lib.optionalAttrs hostHasSolaar {
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
