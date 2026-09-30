# modules/groups/gnome/home.nix
#
# Group `gnome`, user part: neutral GNOME defaults that suit any user.
# Personal GNOME settings (keyboard options, extensions, shortcuts) belong
# to the user, e.g. users/marcin/home/gnome.nix.
{...}: {
  imports = [./qt-theming.nix];

  dconf.settings = {
    # Clock in the top bar
    "org/gnome/desktop/interface" = {
      clock-show-weekday = true;
      clock-show-seconds = true;
      clock-show-date = true;
    };

    # Week numbers in the calendar drop-down
    "org/gnome/desktop/calendar" = {
      show-weekdate = true;
    };

    # Automatic time zone; the location service must be enabled on the
    # system or the time zone set manually.
    "org/gnome/desktop/datetime" = {
      automatic-timezone = true;
    };
  };
}
