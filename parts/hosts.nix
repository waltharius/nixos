# parts/hosts.nix
#
# Fleet outputs generated from the inventory (hosts/fleet.nix, hosts/machines/):
#   nixosConfigurations.<host> - `nixos-rebuild switch --flake .#<host>`
#   colmenaHive                - `colmena apply --on <host>` (Colmena >= 0.5)
#   inventory                  - `nix eval --json .#inventory` (docs, tooling)
#
# Checks (run by `nix flake check`):
#   inventory    - inventory validation (lib/inventory.nix)
#   colmena-hive - every Colmena node evaluates; the result lists the
#                  system derivation of each node
{inputs, ...}: let
  fleet = import ../lib {inherit inputs;};
  hive = inputs.colmena.lib.makeHive fleet.colmena;
in {
  flake = {
    inherit (fleet) nixosConfigurations inventory;
    colmenaHive = hive;
  };

  perSystem = {pkgs, ...}: {
    checks = {
      inventory = pkgs.writeText "inventory.json" (builtins.toJSON fleet.inventory);

      colmena-hive = pkgs.writeText "colmena-hive-drvs.json" (builtins.toJSON (
        builtins.mapAttrs (_: builtins.unsafeDiscardStringContext)
        (hive.evalSelectedDrvPaths (builtins.attrNames fleet.inventory.machines))
      ));
    };
  };
}
