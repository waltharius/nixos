# colmena.nix
# Colmena deployment configuration for all servers
# colmena.nix
{
  inputs,
  system,
}: let
  # Helper to generate server deployment config
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
  nixos-test = mkServerDeployment "nixos-test" "192.168.50.6" ["test" "container" "lxc"];
  #  actual-budget = mkServerDeployment "actual-budget" "192.168.50.7" ["prod" "container" "lxc" "web"];
  cloud-apps = mkServerDeployment "cloud-apps" "192.168.50.8" ["prod" "lxc" "cloud"];
}
