# users/marcin/home/gnome.nix
#
# marcin's personal GNOME settings: keyboard, extensions, run-or-raise
# shortcuts. Active only on hosts where marcin has the `gnome` group; the
# neutral GNOME defaults come from the group (modules/groups/gnome/).
{
  config,
  lib,
  pkgs,
  customPkgs,
  ...
}: let
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
  config = lib.mkIf (lib.elem "gnome" config.fleet.groups) {
    home.packages = gnomeExtensions;

    dconf.settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = map (e: e.extensionUuid) gnomeExtensions;
        disabled-extensions = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
      };

      # GNOME/Wayland reads XKB options from dconf, not from
      # services.xserver.xkb.options (modules/system/locale.nix).
      # Keep both in sync.
      "org/gnome/desktop/input-sources" = {
        sources = [(lib.hm.gvariant.mkTuple ["xkb" "pl"])];
        xkb-options = ["ctrl:nocaps" "shift:both_capslock"];
      };

      "org/gnome/settings-daemon/plugins/power" = {
        lid-close-suspend-with-external-monitor = true;
      };
      "org/gnome/Ptyxis" = {
        text-scale-factor = 1.2;
      };
    };

    xdg.configFile."run-or-raise/shortcuts.conf".text = ''
      <Control><Alt>e,emacs,emacs
      <Super>f,brave,,
      <Super>e,pcmanfm-qt-unwrapped,pcmanfm-qt-raw
      <Super>n,nautilus,org.gnome.Nautilus
      <Super>t,ptyxis,org.gnome.Ptyxis
      <Control>q,signal-desktop,signal
    '';
  };
}
