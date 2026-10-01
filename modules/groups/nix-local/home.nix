# modules/groups/nix-local/home.nix
#
# Group `nix-local`, user part: rebuild this host from its own clone of the
# repository (expected at ~/nixos). For every workstation that updates
# itself; the fleet tools (Colmena, sops, ...) are in `nix-admin`.
{
  pkgs,
  customPkgs,
  ...
}: {
  home.packages = [
    # Rebuilds the local host and shows the package diff (alias `nrs`).
    customPkgs.rebuild-and-diff
    pkgs.nvd
  ];

  programs.bash.shellAliases = {
    nrs = "rebuild-and-diff";
    nrt = "sudo nixos-rebuild test --flake ~/nixos#$(hostname)";
    nrb = "sudo nixos-rebuild boot --flake ~/nixos#$(hostname)";
  };
}
