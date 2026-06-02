# users/marcin/base/desktop-extensions.nix
#
# Desktop-environment-specific HM configuration for marcin.
#
# This module is DE-agnostic by design: it reads the marcin.desktop
# option (set in each host's profile.nix) and activates only the
# configuration that belongs to the active DE(s).
#
# HOW TO ADD A NEW DESKTOP ENVIRONMENT
# -------------------------------------
# 1. Add a new boolean flag in the "feature flags" let-binding below,
#    following the gnome / niri pattern.
# 2. Add the packages, config files, and dconf/wayland settings for
#    that DE inside a lib.mkIf block, guarded by the new flag.
# 3. In the host profile (users/marcin/profiles/<hostname>.nix) add
#    the DE name to marcin.desktop:
#
#      marcin.desktop = [ "gnome" "sway" ];   # both active
#      marcin.desktop = "hyprland";           # single value also works
#
# MULTIPLE DEs ON ONE HOST
# ------------------------
# Setting marcin.desktop to a list activates all listed DEs at once.
# Each DE block is independently guarded, so they compose without
# conflict as long as the underlying HM options don't collide.
#
# REMOVING A DE
# -------------
# Set marcin.desktop to a list that omits the DE name, or set it to []
# to disable all DE-specific configuration while keeping base packages.
{ config, lib, pkgs, customPkgs, ... }:
let
  cfg = config.marcin.desktop;

  # Normalise: accept both a single string and a list of strings.
  desktops = lib.toList cfg;

  # Feature flags — add one line here for each new DE.
  gnome = lib.elem "gnome" desktops;
  niri  = lib.elem "niri"  desktops;
  # sway  = lib.elem "sway"  desktops;   # future example
  # hypr  = lib.elem "hyprland" desktops;

  # GNOME extensions list, defined here so it can be reused in both
  # home.packages and dconf.settings.
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
  # ---------------------------------------------------------------------------
  # Option declaration
  # ---------------------------------------------------------------------------
  options.marcin.desktop = lib.mkOption {
    type    = with lib.types; either str (listOf str);
    default = [];
    example = lib.literalExpression ''[ "gnome" "niri" ]'';
    description = ''
      Desktop environment(s) active on this host. Accepted values:
        "gnome"     — GNOME Shell with extensions
        "niri"      — niri (Wayland tiling compositor)
      A single string is also accepted and is equivalent to a one-element list.
      Set from the host profile: users/marcin/profiles/<hostname>.nix.
    '';
  };

  # ---------------------------------------------------------------------------
  # GNOME configuration (active when "gnome" is in marcin.desktop)
  # ---------------------------------------------------------------------------
  config = lib.mkMerge [
    (lib.mkIf gnome {
      home.packages = gnomeExtensions;

      dconf.settings = {
        "org/gnome/shell" = {
          disable-user-extensions = false;
          enabled-extensions  = map (e: e.extensionUuid) gnomeExtensions;
          disabled-extensions = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        };
        "org/gnome/settings-daemon/plugins/power" = {
          lid-close-suspend-with-external-monitor = true;
        };
      };

      xdg.configFile."run-or-raise/shortcuts.conf".text = ''
        <Control><Alt>e,${pkgs.emacs}/bin/emacs,emacs
        <Super>f,${pkgs.brave}/bin/brave,,
        <Super>e,nautilus,org.gnome.Nautilus
        <Super>t,ptyxis,org.gnome.Ptyxis
        <Control>q,${pkgs.signal-desktop}/bin/signal-desktop,signal
      '';
    })

    # ---------------------------------------------------------------------------
    # Niri configuration (active when "niri" is in marcin.desktop)
    # ---------------------------------------------------------------------------
    # Add niri-specific packages, waybar config, swaylock, mako, etc. here
    # when you start the niri setup on sukkub.
    (lib.mkIf niri {
      # home.packages = [ pkgs.niri pkgs.waybar pkgs.mako ... ];
      # xdg.configFile."niri/config.kdl".text = '''';
    })
  ];
}
