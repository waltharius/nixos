# lib/classes.nix
#
# Host classes: everything a machine gets just by being of a given class.
#
# Each class provides three functions of (name, machine), where `machine` is
# the machine's entry from hosts/inventory.nix:
#   specialArgs - extra arguments passed to every NixOS module of the host
#   modules     - the NixOS module list of the host
#   deploy      - default Colmena `deployment` settings (inventory overrides)
#
# The same module list feeds both nixosConfigurations and colmenaHive, so a
# local `nixos-rebuild --flake .#<host>` and `colmena apply --on <host>`
# always evaluate the same configuration.
#
# NOTE: the ORDER of modules is kept exactly as it was before the flake-parts
# refactor. List-typed options (e.g. environment.systemPackages) merge in
# module order, so reordering changes the resulting derivations.
{inputs}: let
  inherit (inputs) nixpkgs home-manager sops-nix nixvim nix-flatpak disko;

  # Package sets that depend only on the target system.
  pkgsFor = system: {
    pkgs-unstable = import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
    customPkgs = import ../packages {
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    };
  };

  # Home Manager wiring for the admin user on servers and virtual machines.
  nixadmHomeManager = name: {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs;
        hostname = name;
      };
      users.nixadm = import ../users/nixadm/home.nix;
      backupFileExtension = "backup";
      sharedModules = [
        sops-nix.homeManagerModules.sops
      ];
    };
  };
in {
  # Machines fully owned and used by marcin (laptops, desktops).
  workstation = {
    specialArgs = name: machine: let
      p = pkgsFor machine.system;
    in {
      inherit inputs;
      inherit (inputs) self;
      hostname = name;
      inherit (p) pkgs-unstable customPkgs;
    };

    modules = name: machine: let
      p = pkgsFor machine.system;
    in [
      {nixpkgs.config.allowUnfree = true;}

      ../hosts/workstations/${name}/configuration.nix
      ../hosts/workstations/${name}/hardware-configuration.nix
      ../hosts/workstations/${name}/profile.nix

      ../modules/system/boot.nix
      ../modules/system/networking.nix
      ../modules/system/locale.nix
      ../modules/system/secrets.nix
      ../modules/system/sshd.nix
      ../modules/system/wifi.nix
      ../modules/system/base.nix

      # niri is NOT loaded here - it is imported only by the host profile
      # that needs it (modules/system/niri.nix is self-contained and pulls
      # in niri-flake.nixosModules.niri itself).

      sops-nix.nixosModules.sops
      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit inputs;
            hostname = name;
            inherit (p) customPkgs pkgs-unstable;
          };
          users.marcin = import ../users/marcin/home.nix;
          backupFileExtension = "backup";
          sharedModules = [
            nixvim.homeModules.nixvim
            nix-flatpak.homeManagerModules.nix-flatpak
            sops-nix.homeManagerModules.sops
            # niri-flake.homeModules.niri is NOT here - it is injected by
            # modules/home/desktop/niri.nix when a host loads that module.
          ];
        };
      }
    ];

    # Workstations are deployed on the machine itself for now
    # (`colmena apply-local --sudo` or `nixos-rebuild --flake`).
    # Remote deployment comes with the dedicated `deploy` account.
    deploy = _name: _machine: {
      targetHost = null;
      allowLocalDeployment = true;
    };
  };

  # Bare-metal servers, administered through the nixadm account.
  server = {
    specialArgs = name: machine: {
      inherit inputs;
      hostname = name;
      inherit (pkgsFor machine.system) pkgs-unstable;
    };

    modules = name: _machine: [
      ../hosts/physical/${name}/configuration.nix
      # disko is loaded so the disk layout stays part of the configuration.
      # Disk provisioning itself is a one-time install step, not a deploy.
      disko.nixosModules.disko
      sops-nix.nixosModules.sops
      home-manager.nixosModules.home-manager
      (nixadmHomeManager name)
    ];

    # Servers are reached by their static LAN address (via the Tailscale
    # subnet router when away from home). They build on the target so that
    # large closures (CUDA) are not pushed over the network.
    deploy = _name: machine: {
      targetHost = machine.lan.ip;
      targetUser = "nixadm";
      buildOnTarget = true;
    };
  };

  # LXC containers and virtual machines, administered through nixadm.
  virtual = {
    specialArgs = _name: _machine: {};

    modules = name: _machine: [
      ../hosts/virtual/${name}/configuration.nix
      sops-nix.nixosModules.sops
      home-manager.nixosModules.home-manager
      (nixadmHomeManager name)
    ];

    deploy = _name: machine: {
      targetHost = machine.lan.ip;
      targetUser = "nixadm";
    };
  };
}
