# modules/home/desktop/gnome/dconf.nix
# GNOME dconf settings - shared base settings

{...}: {
  dconf.settings = {
    # Power settings - from your config
    "org/gnome/settings-daemon/plugins/power" = {
      # Allow suspend even when external monitors connected
      lid-close-suspend-with-external-monitor = true;
    };

    # Window manager - with your button layout preference
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
    };

    # NOTE: Other settings (theme, hot corners, touchpad) are managed
    # per-user in users/<username>/desktop/gnome/settings.nix
    # This allows each user to have different preferences
  };
}
