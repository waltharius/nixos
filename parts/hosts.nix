# parts/hosts.nix
#
# Fleet outputs generated from the inventory (hosts/fleet.nix, hosts/machines/):
#   nixosConfigurations.<host> - `nixos-rebuild switch --flake .#<host>`
#   colmenaHive                - `colmena apply --on <host>` (Colmena >= 0.5)
#   inventory                  - `nix eval --json .#inventory` (docs, tooling)
#
# Checks (run by `nix flake check`):
#   inventory    - inventory validation (lib/inventory.nix)
#   colmena-hive - every Colmena node evaluates to exactly the same system
#                  derivation as its nixosConfigurations entry, so
#                  `colmena apply` and `nixos-rebuild --flake` build
#                  identical systems; the result lists the derivations
{
  inputs,
  lib,
  ...
}: let
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

      colmena-hive = let
        names = builtins.attrNames fleet.inventory.machines;
        colmenaDrvs =
          builtins.mapAttrs (_: builtins.unsafeDiscardStringContext)
          (hive.evalSelectedDrvPaths names);
        nixosDrvs = lib.genAttrs names (name:
          builtins.unsafeDiscardStringContext
          fleet.nixosConfigurations.${name}.config.system.build.toplevel.drvPath);
        different = builtins.filter (name: colmenaDrvs.${name} != nixosDrvs.${name}) names;
      in
        if different == []
        then pkgs.writeText "colmena-hive-drvs.json" (builtins.toJSON colmenaDrvs)
        else
          throw ''
            Colmena and nixosConfigurations build different systems for: ${lib.concatStringsSep ", " different}
            ${lib.concatMapStrings (n: "  ${n}:\n    colmena: ${colmenaDrvs.${n}}\n    nixos:   ${nixosDrvs.${n}}\n") different}
            See `flakeMetadata` in lib/default.nix.'';
    };
  };
}
