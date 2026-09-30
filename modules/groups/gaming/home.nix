# modules/groups/gaming/home.nix
#
# Group `gaming`, user part. Steam and GameMode are system-wide
# (./nixos.nix); membership in the `gamemode` Unix group is added by the
# group registry (extraGroups).
{pkgs, ...}: {
  home.packages = [pkgs.gnome-mahjongg];
}
