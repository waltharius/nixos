# modules/roles/default.nix
# Role modules export
{...}: {
  imports = [
    ./regular.nix
    ./maintainer.nix
  ];
}
