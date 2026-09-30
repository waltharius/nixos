# modules/groups/notes/home.nix
#
# Group `notes`, user part: note-taking and publishing.
{
  pkgs,
  pkgs-unstable,
  ...
}: {
  home.packages = [
    pkgs-unstable.obsidian
    pkgs.hugo
  ];
}
