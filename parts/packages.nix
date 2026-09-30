# parts/packages.nix
#
# Custom packages from ./packages, exposed as flake outputs
# (`nix build .#<name>`). Hosts receive the same set as `customPkgs`
# through lib/classes.nix.
{inputs, ...}: {
  perSystem = {system, ...}: let
    pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    packages = import ../packages {inherit pkgs;};
  };
}
