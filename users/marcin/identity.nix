# users/marcin/identity.nix
# Marcin's personal identity (git, SSH, SOPS)
{config, ...}: let
  nixos-fonts = "${config.home.homeDirectory}/nixos/fonts";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
in {
  home.username = "marcin";
  home.homeDirectory = "/home/marcin";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # ==========================================
  # Git identity (same everywhere)
  # ==========================================
  programs.git = {
    enable = true;
    settings = {
      user.name = "marcin";
      user.email = "nixosgitemail.frivolous320@passmail.net";
      init.defaultBranch = "main";
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };

  # ==========================================
  # SOPS configuration (same everywhere)
  # ==========================================
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets/ssh.yaml;
  };

  # ==========================================
  # Fonts (same everywhere)
  # ==========================================
  fonts.fontconfig.enable = true;

  # Custom fonts for Emacs (Playpen Sans Hebrew for journal)
  home.file.".local/share/fonts/custom" = {
    source = create_symlink nixos-fonts;
    recursive = true;
  };
}
