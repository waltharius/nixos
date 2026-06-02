# users/marcin/profiles/sukkub.nix
#
# Home Manager profile for marcin on sukkub (ThinkPad P50).
#
# Set marcin.desktop to the DE(s) you want active on this host.
# See users/marcin/base/desktop-extensions.nix for accepted values
# and instructions on adding new desktop environments.
#
# When you are ready to try niri alongside GNOME, change the line below to:
#   marcin.desktop = [ "gnome" "niri" ];
# When you want niri only:
#   marcin.desktop = "niri";
# Then fill in the niri block in base/desktop-extensions.nix.
{ ... }: {
  # sukkub currently runs GNOME Shell, same as azazel.
  # Switch to niri here when ready — no other file needs to change.
  marcin.desktop = "gnome";

  # Add sukkub-specific packages here if needed.
  # For example, NVIDIA monitoring tools:
  # home.packages = [ pkgs.nvtopPackages.nvidia ];
}
