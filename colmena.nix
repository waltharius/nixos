# colmena.nix
# Colmena deployment configuration for all servers
{
  inputs,
  system,
}: let
  # Helper to generate LXC container deployment config
  mkServerDeployment = hostname: ip: tags: {
    deployment = {
      targetHost = ip;
      targetUser = "nixadm";
      inherit tags;
    };

    imports = [
      ./hosts/servers/${hostname}/configuration.nix
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
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
            inputs.sops-nix.homeManagerModules.sops
          ];
        };
      }
    ];
  };

  # Helper for bare-metal servers managed via Colmena (post-install)
  # disko is NOT included here — Colmena deploys config changes only,
  # not disk provisioning. Disk layout is managed by disko-install.
  mkBareMetalDeployment = hostname: ip: tags: {
    deployment = {
      targetHost = ip;
      targetUser = "nixadm";
      inherit tags;
    };

    imports = [
      ./hosts/servers/${hostname}/configuration.nix
      inputs.disko.nixosModules.disko
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
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
            inputs.sops-nix.homeManagerModules.sops
          ];
        };
      }
    ];
  };
in {
  meta = {
    nixpkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    description = "Home infrastructure deployment";
  };

  #=======================#
  #  SERVERS DEFINITIONS  #
  #=======================#

  # LXC containers (Proxmox / Incus)
  nixos-test  = mkServerDeployment "nixos-test"  "192.168.50.6"   [ "test" "container" "lxc" ];
  # actual-budget = mkServerDeployment "actual-budget" "192.168.50.7" [ "prod" "container" "lxc" "web" ];
  cloud-apps  = mkServerDeployment "cloud-apps"  "192.168.50.8"   [ "prod" "lxc" "cloud" ];

  # Bare-metal servers
  # altair: ASUS ProArt X870E, Ryzen 9 7900, 64 GB DDR5, 2× RTX 3090
  # ⚠️  First deployment via nixos-install from live USB (see flake.nix#altair).
  #     Subsequent config changes deployed via: colmena apply --on altair
  altair = mkBareMetalDeployment "altair" "192.168.50.150" [ "server" "baremetal" "gpu" "llm" ];
}
