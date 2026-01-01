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
  };

  outputs = {
    nixpkgs,
    home-manager,
    nix-flatpak,
    sops-nix,
    ...
  } @ inputs: let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    # Import custom packages
    customPackages = import ./packages {inherit pkgs;};

    # Helper function to create host configurations
    mkHost = hostname: system:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs hostname;
          # Unstable packages overlay for specific packages
          pkgs-unstable = import inputs.nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
          customPkgs = customPackages;
        };
        modules = [
          # Allow unfree packages globally
          {nixpkgs.config.allowUnfree = true;}

          # Host-specific configuration
          ./hosts/${hostname}/configuration.nix
          ./hosts/${hostname}/hardware-configuration.nix

          # Shared system modules
          ./modules/system/boot.nix
          ./modules/system/networking.nix
          ./modules/system/locale.nix
          ./modules/system/gnome.nix
          ./modules/system/secrets.nix
          ./modules/system/sshd.nix # SSH server for remote access
          ./modules/system/wifi.nix # WiFi with encrypted passwords
          ./modules/system/auto-upgrade.nix # weekly upgrades with garbage collections
          ./modules/system/certificates.nix
          ./modules/system/base.nix
          ./modules/services/solaar.nix
          #          ./modules/system/plymouth.nix

          # SOPS for system-level secrets
          sops-nix.nixosModules.sops

          # Home Manager integration
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inherit inputs hostname;
                customPkgs = customPackages;
              };
              users.marcin = import ./users/marcin/home.nix;
              backupFileExtension = "backup";

              sharedModules = [
                nix-flatpak.homeManagerModules.nix-flatpak
                sops-nix.homeManagerModules.sops
              ];
            };
          }
        ];
      };
  in {
    # Define all hosts here
    nixosConfigurations = {
      # Test host: Lenovo ThinkPad P50, no battery, nvme
      sukkub = mkHost "sukkub" "x86_64-linux";

      # Production host: ThinkPad T16 Gen3, 128GB RAM, nvme
      azazel = mkHost "azazel" "x86_64-linux";

      # Test VM host for quick config testing
      testvm = mkHost "testvm" "x86_64-linux";
    };

    # Expose packages for nix build, nix shell, etc.
    packages.${system} = customPackages;
  };
}
