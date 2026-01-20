# ./modules/home/desktop/gnome.nix
# This is a file configuring additional Gnome settings for users.
# It should be source in per user home.nix alongsite the ./modules/system/gnome.nix
{...}: {
  dconf.settings = {
    # Clock settings for users in top bar
    "org/gnome/desktop/interface" = {
      clock-show-weekday = true;
      clock-show-seconds = true;
      clock-show-date = true;
    };

    # Week numbers in calendar dropdown
    "org/gnome/desktop/calendar" = {
      show-weekdate = true;
    };

    # Enable automatic TimeZone
    # Proper location must be setup on the system level or manualy
    "org/gnome/desktop/datetime" = {
      automatic-timezone = true;
    };
  };

  ## You can also nested these settings if you prefer
  # "org/gnome/desktop" = {
  #   datetime = {
  #     automatic-timezone = true;
  #   };
  #   calendar = {
  #     show-weekdate = true;
  #   };
  #   interface = {
  #     clock-show-weekday = true;
  #     clock-show-seconds = true;
  #     clock-show-date = true;
  #   };
  # };
}
