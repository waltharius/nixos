{
  description = "Multi-host NixOS configuration with flakes, home-manager, and sops-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.6.0";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim/nixos-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri scrollable-tiling Wayland compositor.
    # nixosModules.niri and homeModules.niri are consumed directly by
    # modules/system/niri.nix (NixOS) and modules/home/desktop/niri.nix (HM).
    # Neither module is loaded globally — they are imported only by the
    # host profile that wants niri (see modules/system/niri.nix for details).
    # niri-flake = {
    #   url = "github:sodiboo/niri-flake";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # Declarative disk partitioning.
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
    #niri-flake,
    disko,
    ...
  } @ inputs: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    customPackages = import ./packages {inherit pkgs;};

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
          ./hosts/workstations/${hostname}/profile.nix

          ./modules/system/boot.nix
          ./modules/system/networking.nix
          ./modules/system/locale.nix
          ./modules/system/secrets.nix
          ./modules/system/sshd.nix
          ./modules/system/wifi.nix
          ./modules/system/base.nix

          # niri is NOT loaded here — it is imported only by the host profile
          # that needs it (modules/system/niri.nix is self-contained and pulls
          # in niri-flake.nixosModules.niri itself).

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
                # niri-flake.homeModules.niri is NOT here — it is injected by
                # modules/home/desktop/niri.nix when a host loads that module.
              ];
            };
          }
        ];
      };

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

    mkPhysicalServer = hostname:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs hostname;
          pkgs-unstable = import inputs.nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
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
      sukkub = mkHost "sukkub" "x86_64-linux";
      azazel = mkHost "azazel" "x86_64-linux";
      altair = mkPhysicalServer "altair";
    };

    colmena = import ./colmena.nix {inherit inputs system;};

    packages.${system} = customPackages;
  };
}
