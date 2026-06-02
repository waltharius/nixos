# users/marcin/profiles/sukkub.nix
#
# Home Manager profile for marcin on sukkub (ThinkPad P50).
#
# marcin.desktop controls which DE-specific HM configuration is activated.
# See users/marcin/base/desktop-extensions.nix for accepted values and
# instructions on adding new desktop environments.
#
# Both "gnome" and "niri" are active so you can log in to either session
# from GDM and switch freely. Remove "gnome" once you are comfortable
# working exclusively in niri.
{ ... }: {
  marcin.desktop = [ "gnome" "niri" ];

  # Add sukkub-specific packages here if needed.
  # For example, extra NVIDIA monitoring:
  # home.packages = [ pkgs.nvtopPackages.nvidia ];
}
