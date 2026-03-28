# colmena.nix
# Colmena deployment configuration for all servers
{
  inputs,
  system,
}: let
  # ---------------------------------------------------------------------------
  # mkVirtualDeployment: LXC containers and VMs
  # Location: hosts/virtual/<hostname>/
  # ---------------------------------------------------------------------------
  mkVirtualDeployment = hostname: ip: tags: {
    deployment = {
      targetHost = ip;
      targetUser = "nixadm";
      inherit tags;
    };

    imports = [
      ./hosts/virtual/${hostname}/configuration.nix
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

  # ---------------------------------------------------------------------------
  # mkPhysicalDeployment: bare-metal servers
  # Location: hosts/physical/<hostname>/
  # Note: disko NOT included here — Colmena deploys config changes only.
  # Disk provisioning is a one-time operation via disko-install from live USB.
  # ---------------------------------------------------------------------------
  mkPhysicalDeployment = hostname: ip: tags: {
    deployment = {
      targetHost = ip;
      targetUser = "nixadm";
      inherit tags;
    };

    imports = [
      ./hosts/physical/${hostname}/configuration.nix
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

  #=========================#
  #  VIRTUAL (LXC / VMs)    #
  #=========================#
  nixos-test  = mkVirtualDeployment "nixos-test"  "192.168.50.6" [ "test" "container" "lxc" ];
  # actual-budget = mkVirtualDeployment "actual-budget" "192.168.50.7" [ "prod" "container" "lxc" "web" ];
  cloud-apps  = mkVirtualDeployment "cloud-apps"  "192.168.50.8" [ "prod" "lxc" "cloud" ];

  #=========================#
  #  PHYSICAL (bare-metal)  #
  #=========================#
  # altair: ASUS ProArt X870E, Ryzen 9 7900, 64 GB DDR5, 2× RTX 3090
  # ⚠️  First deploy via nixos-install from live USB (see flake.nix).
  #     Subsequent config changes: colmena apply --on altair
  altair = mkPhysicalDeployment "altair" "192.168.50.150" [ "server" "baremetal" "gpu" "llm" ];
  # dell = mkPhysicalDeployment "dell" "192.168.50.200" [ "server" "baremetal" "dell" ];  # future
}
