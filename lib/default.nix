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

  # Generated from the whole inventory, imported by every host: fleet
  # known_hosts and the ssh_config texts for admins (lib/ssh.nix).
  fleetSsh = import ./ssh.nix {inherit lib inventory;};

  # Tailscale client of machines with a `tailscale` entry; the others get
  # only its option (lib/tailscale.nix).
  fleetTailscale = import ./tailscale.nix {inherit lib inventory;};

  hostModules = name: machine: (classOf machine).modules name machine ++ [fleetSsh fleetTailscale];
  hostSpecialArgs = name: machine: (classOf machine).specialArgs name machine;

  # `lib.nixosSystem` (used for nixosConfigurations) evaluates with the
  # nixpkgs flake's `lib`, which carries version information, and injects
  # `nixpkgs.flake.source`. Colmena calls nixos/lib/eval-config.nix with the
  # plain `lib` instead, so without this module the same host got a
  # different system derivation (label `26.05pre-git` instead of
  # `26.05.<date>.<rev>`) and no nixpkgs flake registry entry. Colmena nodes
  # import it so that both tools build identical systems; the check
  # `colmena-hive` in parts/hosts.nix enforces the equality.
  flakeMetadata = {
    system.nixos.versionSuffix = inputs.nixpkgs.lib.trivial.versionSuffix;
    system.nixos.revision = inputs.nixpkgs.lib.trivial.revisionWithDefault null;
    nixpkgs.flake.source = inputs.nixpkgs.outPath;
  };

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
      imports = hostModules name machine ++ [flakeMetadata];
    })
    inventory.machines;
}
