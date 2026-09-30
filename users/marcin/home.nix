# users/marcin/home.nix
#
# Personal Home Manager configuration of marcin: settings that follow
# marcin to every host where he has an account, whatever the host's other
# users choose.
#
# What marcin gets on a host is assembled by lib/users.nix from:
#   modules/home/admin/     - admin base (nixvim, bash, ble.sh, starship,
#                             zoxide, atuin), same on every host
#   modules/groups/*/       - the groups listed for marcin in
#                             hosts/machines/<host>.nix
#   this file               - personal settings
#
# Settings that only make sense with a given group check
# config.fleet.groups (see ./home/gnome.nix).
{config, ...}: {
  home.username = "marcin";
  home.homeDirectory = "/home/marcin";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets/ssh.yaml;
  };

  imports = [
    ./home/git.nix
    ./home/ssh.nix
    ./home/ssh-askpass.nix
    ./home/shell.nix
    ./home/fonts.nix
    ./home/packages.nix
    ./home/nextcloud.nix
    ./home/autostart.nix
    ./home/solaar.nix
    ./home/gnome.nix
  ];
}
