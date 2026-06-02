# users/marcin/profiles/azazel.nix
#
# Home Manager profile for marcin on azazel (ThinkPad T16 Gen3).
#
# Set marcin.desktop to the DE(s) you want active on this host.
# See users/marcin/base/desktop-extensions.nix for accepted values
# and instructions on adding new desktop environments.
{ ... }: {
  # azazel runs GNOME Shell.
  marcin.desktop = "gnome";

  # Host-specific shell aliases (merged with base bash aliases).
  programs.bash.shellAliases = {
    myalias = "echo 'custom for marcin'";
  };

  # Add azazel-specific packages here if needed.
  # home.packages = [ ... ];
}
