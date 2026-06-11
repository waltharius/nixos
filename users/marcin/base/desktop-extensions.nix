# users/marcin/base/desktop-extensions.nix
#
# Desktop-environment-specific HM configuration for marcin.
#
# IMPORTANT: Desktop environment modules (gnome.nix, niri.nix, …) must be
# listed in the static imports list in users/marcin/home.nix — NOT imported
# here inside lib.mkIf blocks. The Nix module system resolves imports before
# evaluating conditions, so conditional imports are not possible.
#
# This file handles only configuration that cannot live in the DE module
# itself because it references options declared by another module (e.g.
# GNOME extensions require gnomeExtensions list defined here).
#
# HOW TO SWITCH / ADD DEs
# -----------------------
# 1. Add the DE module to the static imports in users/marcin/home.nix.
# 2. Add a feature flag (lib.elem … desktops) in this file if you need
#    DE-specific config here (e.g. dconf, run-or-raise shortcuts).
# 3. Set marcin.desktop in the host profile:
#      marcin.desktop = [ "gnome" "niri" ];   # both active
#      marcin.desktop = "niri";               # niri only
#      marcin.desktop = [ "gnome" "hyprland" ]; # future example
{
  config,
  lib,
  pkgs,
  customPkgs,
  ...
}: let
  cfg = config.marcin.desktop;
  desktops = lib.toList cfg;

  # Feature flags — one per DE.
  gnome = lib.elem "gnome" desktops;
  # niri config lives entirely in modules/home/desktop/niri.nix.
  # No extra config needed here for niri.

  gnomeExtensions = with pkgs.gnomeExtensions; [
    appindicator
    run-or-raise
    gsconnect
    just-perfection
    power-tracker
    screen-brightness-governor
    shu-zhi
    window-is-ready-remover
    focused-window-d-bus
    customPkgs.solaar-extension
  ];
in {
  options.marcin.desktop = lib.mkOption {
    type = with lib.types; either str (listOf str);
    default = [];
    example = lib.literalExpression ''[ "gnome" "niri" ]'';
    description = ''
      Desktop environment(s) active on this host. Accepted values:
        "gnome"     — GNOME Shell with extensions
        "niri"      — niri scrollable-tiling Wayland compositor
      A single string is equivalent to a one-element list.
      Set in: users/marcin/profiles/<hostname>.nix
    '';
  };

  config = lib.mkIf gnome {
    home.packages = gnomeExtensions;

    dconf.settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = map (e: e.extensionUuid) gnomeExtensions;
        disabled-extensions = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
      };
      "org/gnome/settings-daemon/plugins/power" = {
        lid-close-suspend-with-external-monitor = true;
      };
      "org/gnome/Ptyxis" = {
        text-scale-factor = 1.2;
      };
    };

    xdg.configFile."run-or-raise/shortcuts.conf".text = ''
      <Control><Alt>e,${pkgs.emacs}/bin/emacs,emacs
      <Super>f,${pkgs.brave}/bin/brave,,
      <Super>e,nautilus,org.gnome.Nautilus
      <Super>t,ptyxis,org.gnome.Ptyxis
      <Control>q,${pkgs.signal-desktop}/bin/signal-desktop,signal
    '';
  };
}
