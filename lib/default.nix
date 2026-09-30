# lib/default.nix
#
# Turns the validated inventory into flake outputs.
#
#   inventory           - validated inventory (hosts/fleet.nix + hosts/machines/)
#   nixosConfigurations - one NixOS system per machine
#   colmena             - raw Colmena hive; pass it to colmena.lib.makeHive
#
# Both nixosConfigurations and the hive use the same module list and the
# same specialArgs per machine (from lib/classes.nix), so nothing about a
# host is defined twice.
{inputs}: let
  inherit (inputs.nixpkgs) lib;

  classes = import ./classes.nix {inherit inputs;};
  inventory = import ./inventory.nix {inherit lib classes;};

  classOf = machine: classes.${machine.class};

  hostModules = name: machine: (classOf machine).modules name machine;
  hostSpecialArgs = name: machine: (classOf machine).specialArgs name machine;

  # Class defaults, then per-machine overrides from the inventory.
  hostDeployment = name: machine:
    (classOf machine).deploy name machine
    // (machine.deploy or {})
    // {tags = machine.tags or [];};
in {
  inherit inventory;

  nixosConfigurations =
    lib.mapAttrs (name: machine:
      lib.nixosSystem {
        inherit (machine) system;
        specialArgs = hostSpecialArgs name machine;
        modules = hostModules name machine;
      })
    inventory.machines;

  colmena =
    {
      meta = {
        description = "Home infrastructure deployment";
        # Default package set for all nodes. Nodes on another architecture
        # (e.g. aarch64 Raspberry Pis) will need meta.nodeNixpkgs entries.
        nixpkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        nodeSpecialArgs = lib.mapAttrs hostSpecialArgs inventory.machines;
        # A bare `colmena apply` must not touch the whole fleet by accident:
        # always select nodes with `--on <host>` or `--on @<tag>`.
        allowApplyAll = false;
      };
    }
    // lib.mapAttrs (name: machine: {
      deployment = hostDeployment name machine;
      imports = hostModules name machine;
    })
    inventory.machines;
}
