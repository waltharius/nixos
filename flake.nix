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
    # Required for bare-metal servers: LUKS2/btrfs layout and one-command
    # disko-install workflow from live USB.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
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

    customPackages = import ./packages {inherit pkgs;};

    # ---------------------------------------------------------------------------
    # mkHost: physical workstations (laptops/desktops with desktop environment)
    # Location: hosts/workstations/<hostname>/
    # ---------------------------------------------------------------------------
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
          ./hosts/workstations/${hostname}/configuration.nix
          ./hosts/workstations/${hostname}/hardware-configuration.nix
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

    # ---------------------------------------------------------------------------
    # mkVirtual: LXC containers and VMs (Colmena-managed, no disko)
    # Location: hosts/virtual/<hostname>/
    # ---------------------------------------------------------------------------
    mkVirtual = hostname:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/virtual/${hostname}/configuration.nix
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

    # ---------------------------------------------------------------------------
    # mkPhysicalServer: bare-metal servers (disko, LUKS2, full hardware)
    # Location: hosts/physical/<hostname>/
    # Install from live USB:
    #   nix run github:nix-community/disko -- --mode disko \
    #     ./hosts/physical/<hostname>/disko.nix
    #   nixos-install --flake .#<hostname> --no-root-password
    # ---------------------------------------------------------------------------
    mkPhysicalServer = hostname:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs hostname;
        };
        modules = [
          ./hosts/physical/${hostname}/configuration.nix
          disko.nixosModules.disko
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

  in {
    nixosConfigurations = {
      # Workstations (hosts/workstations/)
      sukkub = mkHost "sukkub" "x86_64-linux";
      azazel = mkHost "azazel" "x86_64-linux";

      # Physical bare-metal servers (hosts/physical/)
      # Install: nix run github:nix-community/disko -- --mode disko \
      #            ./hosts/physical/altair/disko.nix
      #          nixos-install --flake .#altair --no-root-password
      altair = mkPhysicalServer "altair";
      # dell   = mkPhysicalServer "dell";  # future: Dell T5610
    };

    # Colmena deployment for all servers (virtual + physical post-install)
    colmena = import ./colmena.nix {inherit inputs system;};

    packages.${system} = customPackages;
  };
}
