# lib/users.nix
#
# Turns `machines.<host>.users` from hosts/inventory.nix into NixOS modules:
#
#   machines.<host>.users.<user>.groups = ["gnome" "office"];
#
# For every user of a host this adds
#   - the account:           users/<user>/account.nix
#   - Unix groups required by the user's program groups (registry field
#     `extraGroups`, e.g. `gamemode` for `gaming`)
#   - Home Manager:          users/<user>/home.nix (personal settings)
#                            + modules/home/admin/ (admin accounts only)
#                            + the user part of each chosen group
# and for the host as a whole
#   - the system part of every group chosen by at least one of its users.
#
# Modules are selected with import lists, not with enable options: a host
# evaluates only what its users actually use.
{lib}: let
  groups = import ../modules/groups;

  # Accounts that administer machines. They get the same editor and shell
  # on every host (modules/home/admin/).
  adminAccounts = ["marcin" "nixadm" "keeper"];

  usersOf = machine: machine.users or {};
  groupsOf = user: user.groups or [];
in {
  inherit groups adminAccounts;

  # NixOS modules for the accounts and the system parts of the groups.
  nixosModules = machine: let
    users = usersOf machine;
    hostGroups = lib.unique (lib.concatMap groupsOf (lib.attrValues users));
  in
    lib.mapAttrsToList (name: _: ../users/${name}/account.nix) users
    ++ lib.concatMap (g: lib.optional (groups.${g} ? nixos) groups.${g}.nixos) hostGroups
    ++ [
      {
        users.users =
          lib.mapAttrs (_: user: {
            extraGroups = lib.concatMap (g: groups.${g}.extraGroups or []) (groupsOf user);
          })
          users;
      }
    ];

  # Value for `home-manager.users`.
  homeUsers = machine:
    lib.mapAttrs (name: user: {
      imports =
        [
          ../modules/home/fleet.nix
          ../users/${name}/home.nix
        ]
        ++ lib.optional (lib.elem name adminAccounts) ../modules/home/admin
        ++ lib.concatMap (g: lib.optional (groups.${g} ? home) groups.${g}.home) (groupsOf user);

      fleet.groups = groupsOf user;
    })
    (usersOf machine);
}
