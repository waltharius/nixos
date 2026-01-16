# modules/roles/maintainer.nix
# Maintainer role: sudo access, CLI tools, minimal GUI (laptops only)
{
  lib,
  pkgs,
  userConfig,
  ...
}: let
  username = userConfig.username;
  hasMaintainerRole = builtins.elem "maintainer" userConfig.roles;
  isServer = userConfig.isServer or false;
in {
  # ==========================================
  # Imports - ALWAYS import, activation is conditional
  # ==========================================
  imports = [
    ../home/shell/bash.nix
    ../home/shell/starship.nix
    ../home/terminal/tmux.nix
    ../home/tools/atuin.nix
    ../home/tools/zoxide.nix
    ../utils/yazi.nix
    ../utils/nixvim
    ../services/syncthing.nix
    ../services/ssh.nix
    ../services/ssh-askpass.nix
    (../../users + "/${username}/preferences.nix")
  ];

  # ==========================================
  # Configuration - Activate only if user has maintainer role
  # ==========================================
  config = lib.mkIf hasMaintainerRole {
    # CLI tools for maintenance
    home.packages = with pkgs;
      [
        # System tools
        htop
        btop
        lsof
        procfd
        usbutils
        pciutils

        # Network tools
        curl
        wget
        dig
        rclone
        openssl

        # Development tools
        git
        ripgrep
        fd
        tree

        # File utilities
        yazi
        eza
        blesh

        # Nix ecosystem tools
        nixpkgs-fmt
        nvd
        nh
        sops
        age
        nil # Nix LSP
        nix-prefetch-github

        # Text processing
        fastfetch
      ]
      ++ lib.optionals (!isServer) [
        # GUI apps for maintenance on laptops
        brave # Browser for debugging
        ptyxis # Terminal
        nextcloud-client # For accessing files
        colmena # DEPLOYMENT TOOL - only on laptops!
      ];
  };
}
