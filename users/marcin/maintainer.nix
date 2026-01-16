# users/marcin/maintainer.nix
# CLI tools and shell config for remote maintenance
# Use this on family laptops where you only need SSH access

{ pkgs, customPkgs ? {}, ... }: {
  imports = [
    ./core.nix
    ../../modules/services/syncthing.nix
    ../../modules/services/ssh.nix
    ../../modules/services/ssh-askpass.nix
    ../../modules/utils/yazi.nix
    ../../modules/utils/nixvim
    ../../modules/home/tools/zoxide.nix
    ../../modules/home/tools/atuin.nix
    ../../modules/home/shell/bash.nix
    ../../modules/home/shell/starship.nix
    ../../modules/home/terminal/tmux.nix
  ];

  # CLI tools for maintenance
  home.packages = with pkgs; [
    # Custom packages
    customPkgs.rebuild-and-diff
    customPkgs.track-package
    customPkgs.track-package-deps
    customPkgs.track-package-py
    customPkgs.track-package-simple

    # Development tools
    ripgrep
    fd
    tree
    curl
    git

    # Shell utilities
    ptyxis
    blesh
    eza
    zoxide
    starship
    fastfetch
    atuin
    btop
    htop
    lsof
    procfd
    usbutils
    pciutils
    wget
    rclone
    rclone-ui
    dig
    openssl

    # Nix tools
    nix-prefetch-github
    sops
    age
    nil
    nixpkgs-fmt
    nvd
    nh
    colmena

    # File managers
    yazi
  ];
}
