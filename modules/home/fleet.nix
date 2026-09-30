# modules/home/fleet.nix
#
# Makes the inventory data of a user visible inside Home Manager, so that
# personal modules can adapt to the groups the user has on a given host,
# e.g. `lib.elem "gnome" config.fleet.groups`. Set by lib/users.nix.
{lib, ...}: {
  options.fleet.groups = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "Program groups of this user on this host (hosts/machines/<host>.nix).";
  };
}
