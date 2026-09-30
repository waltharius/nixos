# modules/groups/web/home.nix
#
# Group `web`, user part. Brave itself is installed system-wide by the
# system part (./nixos.nix) together with its policies. Hugo builds the
# sites published from Emacs (ox-hugo).
{
  pkgs,
  pkgs-unstable,
  ...
}: {
  imports = [./buku.nix];

  home.packages = [
    pkgs-unstable.vivaldi
    pkgs.hugo
  ];

  services.flatpak.packages = [
    "org.jdownloader.JDownloader"
  ];
}
