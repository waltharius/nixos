# hosts/

The inventory: every machine of the fleet and the settings shared by all
of them. It is plain data, loaded and validated by `lib/inventory.nix` on
every evaluation (`nix flake check`, `nixos-rebuild`, `colmena`).

| Path                         | Contents                                         |
| ---------------------------- | ------------------------------------------------ |
| `fleet.nix`                  | fleet-wide settings: LAN prefix, DHCP pool       |
| `machines/<host>.nix`        | one NixOS machine; the file name is the host name |
| `workstations/<host>/`       | host files of class `workstation`                |
| `physical/<host>/`           | host files of class `server`                     |
| `virtual/<host>/`            | host files of class `virtual`                    |

Every `*.nix` file in `machines/` is loaded automatically.

The inventory is exported as JSON for external tooling:
`nix eval --json .#inventory`.

## Machine fields (`machines/<host>.nix`)

| Field         | Required            | Meaning |
| ------------- | ------------------- | ------- |
| `class`       | yes                 | `workstation`, `server` or `virtual` (see `lib/classes.nix`) |
| `system`      | yes                 | Nix system, e.g. `x86_64-linux` |
| `description` | no                  | free text, shown in the exported inventory |
| `tags`        | no                  | Colmena tags; select with `colmena apply --on @<tag>` |
| `lan.ip`      | server, virtual     | static LAN address. For laptops only documentation of the DHCP reservation (laptops roam between networks) |
| `deploy`      | no                  | Colmena deployment settings; override the class defaults from `lib/classes.nix` |
| `users`       | yes                 | accounts on the machine and the program groups each one uses: `users.<n>.groups = [ ... ]`. The account must exist in `users/<n>/account.nix`, the groups in `modules/groups/default.nix`. The host gets the system part of every group of every user (see `lib/users.nix`). Servers and virtual machines must have `nixadm` |

The shape deliberately mirrors Clan's inventory (`machines.<n>.tags`,
`machines.<n>.deploy.targetHost`, `machines.<n>.description`) so that a
later migration to Clan stays mostly a mechanical rename.

## Validation

Evaluation aborts with a list of all problems when a machine file name is
not a valid host name, a class is unknown, `system` is missing, a server or
virtual machine has no `lan.ip` or no `nixadm`, an address is outside the
LAN, inside the router's DHCP pool or used twice, or a user or group does
not exist.
