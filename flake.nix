{
  description = "Multi-host NixOS configuration with flakes, home-manager, and sops-nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Flake structure: every output is defined by a module in ./parts.
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Deployment tool. Pinned to a release tag so that the CLI (from this
    # input) and the hive format produced by colmena.lib.makeHive always
    # match. Colmena keeps its own nixpkgs: that is the combination its
    # maintainers test and cache (colmena.cachix.org).
    colmena.url = "github:nix-community/colmena/v0.5.0";

    # Git pre-commit hooks, installed by `nix develop` (see parts/dev.nix).
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # Declarative disk partitioning.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # All outputs are assembled by flake-parts from the modules below.
  # Machines are declared in hosts/machines/<host>.nix; see lib/ for how the
  # inventory becomes nixosConfigurations and the Colmena hive.
  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];

      imports = [
        ./parts/hosts.nix
        ./parts/packages.nix
        ./parts/dev.nix
        ./parts/secrets.nix
        ./parts/new-host.nix
        ./parts/install-host.nix
        ./parts/fleet.nix
      ];
    };
}
