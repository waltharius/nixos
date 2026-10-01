# modules/groups/nix-admin/home.nix
#
# Group `nix-admin`, user part: tools for working on this repository
# (expected at ~/nixos) and deploying the fleet. Rebuilding the local host
# (`nrs` and friends) is the separate group `nix-local`.
{
  pkgs,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    nix-prefetch-github
    sops
    age
    nil
    nixpkgs-fmt
    nh
    # Colmena comes from the flake input, not from nixpkgs: the CLI must
    # match the hive format produced by colmena.lib.makeHive (parts/hosts.nix).
    inputs.colmena.packages.${pkgs.stdenv.hostPlatform.system}.colmena
  ];

  # Writing installation images to USB drives.
  services.flatpak.packages = [
    "org.fedoraproject.MediaWriter"
  ];
}
