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
# Accounts, program groups and Home Manager users come from the host's
# `users` in hosts/inventory.nix (see lib/users.nix).
#
# NOTE: list-typed options (e.g. environment.systemPackages) merge in
# module order, so reordering modules changes the system derivation (not
# the behaviour).
{inputs}: let
  inherit (inputs) nixpkgs home-manager sops-nix nixvim nix-flatpak disko;
  inherit (nixpkgs) lib;

  userLib = import ./users.nix {inherit lib;};

  # Inventory entry of a machine plus its name; passed to NixOS and Home
  # Manager modules as `host` (e.g. `host.class`).
  hostInfo = name: machine: machine // {inherit name;};

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

  # Home Manager for all users of a host (servers and virtual machines).
  serverHomeManager = name: machine: {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {
        inherit inputs;
        hostname = name;
        host = hostInfo name machine;
      };
      users = userLib.homeUsers machine;
      backupFileExtension = "backup";
      sharedModules = [
        sops-nix.homeManagerModules.sops
        nixvim.homeModules.nixvim
      ];
    };
  };
in {
  # Laptops and desktops used by people (for now: marcin's own).
  workstation = {
    specialArgs = name: machine: let
      p = pkgsFor machine.system;
    in {
      inherit inputs;
      inherit (inputs) self;
      hostname = name;
      host = hostInfo name machine;
      inherit (p) pkgs-unstable customPkgs;
    };

    modules = name: machine: let
      p = pkgsFor machine.system;
    in
      [
        {nixpkgs.config.allowUnfree = true;}

        ../hosts/workstations/${name}/configuration.nix
        ../hosts/workstations/${name}/hardware-configuration.nix
        ../hosts/workstations/${name}/custom.nix

        # --- every workstation ---
        ../modules/system/boot.nix
        ../modules/system/networking.nix
        ../modules/system/locale.nix
        ../modules/system/secrets.nix
        ../modules/system/sshd.nix
        ../modules/system/wifi.nix
        ../modules/system/base.nix
        ../modules/system/fonts.nix
        ../modules/system/certificates.nix
        ../modules/system/plymouth.nix
        ../modules/system/sudo.nix
        ../modules/system/hardware/audio.nix
        ../modules/system/hardware/printing.nix
        ../modules/system/hardware/flatpak.nix

        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit inputs;
              hostname = name;
              host = hostInfo name machine;
              inherit (p) customPkgs pkgs-unstable;
            };
            users = userLib.homeUsers machine;
            backupFileExtension = "backup";
            sharedModules = [
              nixvim.homeModules.nixvim
              nix-flatpak.homeManagerModules.nix-flatpak
              sops-nix.homeManagerModules.sops
            ];
          };
        }
      ]
      ++ userLib.nixosModules machine;

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
      host = hostInfo name machine;
      inherit (pkgsFor machine.system) pkgs-unstable;
    };

    modules = name: machine:
      [
        ../hosts/physical/${name}/configuration.nix
        # disko is loaded so the disk layout stays part of the configuration.
        # Disk provisioning itself is a one-time install step, not a deploy.
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        (serverHomeManager name machine)
      ]
      ++ userLib.nixosModules machine;

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
    specialArgs = name: machine: {
      host = hostInfo name machine;
    };

    modules = name: machine:
      [
        ../hosts/virtual/${name}/configuration.nix
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        (serverHomeManager name machine)
      ]
      ++ userLib.nixosModules machine;

    deploy = _name: machine: {
      targetHost = machine.lan.ip;
      targetUser = "nixadm";
    };
  };
}
