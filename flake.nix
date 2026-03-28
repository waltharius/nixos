{
  description = "Multi-host NixOS configuration with flakes, home-manager, and sops-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning.
    # Required for altair's LUKS2/btrfs layout and the one-command
    # disko-install workflow from live USB.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";  # Avoid duplicate nixpkgs closures
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    nix-flatpak,
    sops-nix,
    nixvim,
    disko,
    ...
  } @ inputs: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    # Import custom packages
    customPackages = import ./packages {inherit pkgs;};

    # Helper function to create workstation configurations
    mkHost = hostname: system:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs hostname;
          inherit (inputs) self;
          pkgs-unstable = import inputs.nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
          customPkgs = customPackages;
        };
        modules = [
          {nixpkgs.config.allowUnfree = true;}
          ./hosts/${hostname}/configuration.nix
          ./hosts/${hostname}/hardware-configuration.nix
          ./modules/system/boot.nix
          ./modules/system/networking.nix
          ./modules/system/locale.nix
          ./modules/system/gnome.nix
          ./modules/system/secrets.nix
          ./modules/system/sshd.nix
          ./modules/system/wifi.nix
          ./modules/system/auto-upgrade.nix
          ./modules/system/certificates.nix
          ./modules/system/base.nix
          ./modules/services/solaar.nix
          ./modules/system/plymouth.nix
          ./modules/system/sudo.nix
          ./modules/system/brave.nix
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inherit inputs hostname;
                customPkgs = customPackages;
                pkgs-unstable = import inputs.nixpkgs-unstable {
                  inherit system;
                  config.allowUnfree = true;
                };
              };
              users.marcin = import ./users/marcin/home.nix;
              backupFileExtension = "backup";
              sharedModules = [
                nixvim.homeModules.nixvim
                nix-flatpak.homeManagerModules.nix-flatpak
                sops-nix.homeManagerModules.sops
              ];
            };
          }
        ];
      };

    # Helper for LXC container servers (Colmena-managed, no disko)
    mkServer = hostname:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/servers/${hostname}/configuration.nix
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inherit inputs;
                hostname = hostname;
              };
              users.nixadm = import ./users/nixadm/home.nix;
              backupFileExtension = "backup";
              sharedModules = [
                sops-nix.homeManagerModules.sops
              ];
            };
          }
        ];
      };

    # Helper for bare-metal servers with disko (nixos-install workflow)
    # Usage from live USB:
    #   nix run github:nix-community/disko -- --mode disko ./hosts/servers/<name>/disko.nix
    #   nixos-install --flake .#<name> --no-root-password
    mkBareMetal = hostname:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs hostname;
        };
        modules = [
          # Host-specific configuration (imports hardware + base-baremetal)
          ./hosts/servers/${hostname}/configuration.nix

          # disko module: evaluates disko.devices, generates systemd mount
          # units and activation scripts for the declarative disk layout.
          disko.nixosModules.disko

          # SOPS-nix for secret management
          sops-nix.nixosModules.sops

          # Home Manager for nixadm user environment
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inherit inputs;
                hostname = hostname;
              };
              users.nixadm = import ./users/nixadm/home.nix;
              backupFileExtension = "backup";
              sharedModules = [
                sops-nix.homeManagerModules.sops
              ];
            };
          }
        ];
      };

  in {
    nixosConfigurations = {
      # Workstations
      sukkub = mkHost "sukkub" "x86_64-linux";
      azazel = mkHost "azazel" "x86_64-linux";

      # Bare-metal servers (disko-managed disks, nixos-install workflow)
      # altair: ASUS ProArt X870E, Ryzen 9 7900, 64GB DDR5, 2× RTX 3090
      # Reinstall: nix run github:nix-community/disko -- --mode disko \
      #              ./hosts/servers/altair/disko.nix
      #            nixos-install --flake .#altair --no-root-password
      altair = mkBareMetal "altair";
    };

    # Colmena deployment (LXC containers + bare-metal via SSH)
    colmena = import ./colmena.nix {inherit inputs system;};

    packages.${system} = customPackages;
  };
}
