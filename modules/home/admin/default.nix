# modules/home/admin/default.nix
#
# Base of every admin account (marcin, nixadm, keeper) on every host,
# whatever groups the account has: the same editor and the same shell
# everywhere. Applied by lib/users.nix to the accounts listed in
# `adminAccounts` there.
{...}: {
  imports = [
    ./bash.nix
    ./starship.nix
    ./zoxide.nix
    ./atuin.nix
    ./nixvim
  ];

  # eza backs the ls aliases in ./bash.nix.
  programs.eza.enable = true;

  programs.git.enable = true;
}
