# modules/groups/nix-admin/home.nix
#
# Group `nix-admin`, user part: tools for working on this repository
# (expected at ~/nixos) and deploying the fleet.
{
  pkgs,
  inputs,
  customPkgs,
  ...
}: {
  home.packages = with pkgs; [
    # Rebuilds the local host and shows the package diff (alias `nrs`).
    customPkgs.rebuild-and-diff

    nix-prefetch-github
    sops
    age
    nil
    nixpkgs-fmt
    nvd
    nh
    # Colmena comes from the flake input, not from nixpkgs: the CLI must
    # match the hive format produced by colmena.lib.makeHive (parts/hosts.nix).
    inputs.colmena.packages.${pkgs.stdenv.hostPlatform.system}.colmena
  ];

  programs.bash.shellAliases = {
    nrs = "rebuild-and-diff";
    nrt = "sudo nixos-rebuild test --flake ~/nixos#$(hostname)";
    nrb = "sudo nixos-rebuild boot --flake ~/nixos#$(hostname)";
  };

  # Writing installation images to USB drives.
  services.flatpak.packages = [
    "org.fedoraproject.MediaWriter"
  ];
}
