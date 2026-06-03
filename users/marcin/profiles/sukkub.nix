# users/marcin/profiles/sukkub.nix
#
# Home Manager profile for marcin on sukkub (ThinkPad P50).
#
# marcin.desktop controls which DE-specific HM configuration is activated.
# See users/marcin/base/desktop-extensions.nix for accepted values and
# instructions on adding new desktop environments.
#
# TO RE-ENABLE NIRI on sukkub:
#   1. In hosts/workstations/sukkub/profile.nix add:
#        imports = [ ../../../modules/system/niri.nix ];
#        home-manager.users.marcin.imports = [
#          ../../../modules/home/desktop/niri.nix
#        ];
#   2. Change marcin.desktop below to [ "gnome" "niri" ].
#   modules/system/niri.nix is self-contained — that single import
#   brings the NixOS session registration, greetd, and all system deps.
{ ... }: {
  marcin.desktop = "gnome";

  # Add sukkub-specific packages here if needed.
  # For example, extra NVIDIA monitoring:
  # home.packages = [ pkgs.nvtopPackages.nvidia ];
}
