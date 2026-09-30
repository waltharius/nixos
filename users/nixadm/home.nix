# users/nixadm/home.nix
#
# Personal Home Manager configuration of nixadm. The shell, prompt,
# history and editor come from the admin base (modules/home/admin/),
# identical to marcin's.
{...}: {
  home.username = "nixadm";
  home.homeDirectory = "/home/nixadm";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  programs.bash.shellAliases = {
    # NixOS shortcuts for remote management
    nrs = "sudo nixos-rebuild switch";
    nrt = "sudo nixos-rebuild test";
  };

  programs.git.settings = {
    user.name = "nixadm";
    user.email = "nixadm@home.lan";
    init.defaultBranch = "main";
  };
}
