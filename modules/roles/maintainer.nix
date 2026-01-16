# modules/roles/maintainer.nix
# Maintainer role: sudo access, CLI tools, minimal GUI (laptops only)

{ config, lib, pkgs, userConfig, ... }:

let
  username = userConfig.username;
  hasMaintainerRole = builtins.elem "maintainer" userConfig.roles;
  isServer = userConfig.isServer or false;
in
{
  config = lib.mkIf hasMaintainerRole {
    # Shell & terminal environment
    imports = [
      ../home/shell/bash.nix
      ../home/shell/starship.nix  # Handles server/laptop variants automatically
      ../home/terminal/tmux.nix
      ../home/tools/atuin.nix
      ../home/tools/zoxide.nix
      ../utils/yazi.nix
      ../utils/nixvim
      ../home/tools/hugo.nix  # For documentation
      ../home/tools/buku.nix  # For bookmarks
      
      # Services
      ../services/syncthing.nix
      ../services/ssh.nix
      ../services/ssh-askpass.nix
      
      # User's personal preferences
      (../../users + "/${username}/preferences.nix")
    ];
    
    # CLI tools for maintenance
    home.packages = with pkgs; [
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
      rclone-ui
      openssl
      
      # Development tools
      git
      ripgrep
      fd
      tree
      
      # File utilities
      yazi
      
      # Nix ecosystem tools
      nixpkgs-fmt
      nvd
      nh
      sops
      age
      nil  # Nix LSP
      nix-prefetch-github
      
      # Text processing
      fastfetch
      
      # Minimal GUI (only on laptops where you do maintenance)
      # Colmena is laptop-only - servers don't deploy other machines
    ] ++ lib.optionals (!isServer) [
      # GUI apps for maintenance on laptops
      brave            # Browser for debugging
      gnome-text-editor  # Simple text editor (works in any DE)
      ptyxis           # Terminal
      nextcloud-client # For accessing files
      
      # DEPLOYMENT TOOL - only on laptops!
      colmena          # For deploying to other machines
    ];
  };
}
