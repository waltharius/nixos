# modules/groups/default.nix
#
# Registry of program groups. A group is a set of programs a user chooses
# in hosts/machines/<host>.nix:
#
#   machines.<host>.users.<user>.groups = ["gnome" "office" ...];
#
# Each group can have:
#   nixos       - NixOS module with the system part (desktop session,
#                 services, system-wide policies). A host imports the
#                 system parts of the groups of ALL its users.
#   home        - Home Manager module with the user part (packages,
#                 settings, Flatpak apps). Imported only for the users
#                 who chose the group.
#   extraGroups - Unix groups a user of this group must be a member of.
#
# Only groups listed here exist: a typo in the inventory is reported by
# the inventory validation (lib/inventory.nix) instead of being ignored.
#
# Programs every admin account needs on every host (nixvim, bash, ble.sh,
# starship, zoxide, atuin) are not a group: see modules/home/admin/.
# Hardware support is not a group either: it belongs to the host
# (hosts/<class>/<host>/custom.nix).
{
  # GNOME session (GDM) and neutral GNOME defaults.
  gnome = {
    nixos = ./gnome/nixos.nix;
    home = ./gnome/home.nix;
  };

  # Runtime dependencies of the Emacs configuration (kept in its own repo).
  emacs.home = ./emacs/home.nix;

  # Office suites, bibliography, e-books, PDF tools, Obsidian.
  office.home = ./office/home.nix;

  # Full TeX Live. Large, so it is a group of its own.
  latex.home = ./latex/home.nix;

  # Browsers (Brave with system-wide policies), bookmarks, downloads, Hugo.
  web = {
    nixos = ./web/nixos.nix;
    home = ./web/home.nix;
  };

  # Messaging and e-mail.
  comms.home = ./comms/home.nix;

  # Music, podcasts, photos.
  media.home = ./media/home.nix;

  # Steam, GameMode and games.
  gaming = {
    nixos = ./gaming/nixos.nix;
    home = ./gaming/home.nix;
    extraGroups = ["gamemode"];
  };

  # Tools for managing this repository and the fleet.
  nix-admin.home = ./nix-admin/home.nix;

  # Command-line utilities that are handy but not essential.
  cli.home = ./cli/home.nix;
}
