# modules/groups/web/home.nix
#
# Group `web`, user part. Brave itself is installed system-wide by the
# system part (./nixos.nix) together with its policies.
{pkgs-unstable, ...}: {
  imports = [./buku.nix];

  home.packages = [pkgs-unstable.vivaldi];

  services.flatpak.packages = [
    "org.jdownloader.JDownloader"
  ];
}
