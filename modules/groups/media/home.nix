# modules/groups/media/home.nix
#
# Group `media`, user part: music, podcasts, photos, ambient sounds.
{pkgs, ...}: {
  home.packages = with pkgs; [
    spotify
    spotify-player
    gnome-podcasts
    shotwell
    blanket
  ];
}
