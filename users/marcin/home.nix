# Home Manager configuration for user marcin
# Combines configuration from both previous setups
{
  config,
  pkgs,
  lib,
  customPkgs ? {}, # Optional with empty default
  ...
}: let
  # Dotfiles symlink helper
  # dotfiles = "${config.home.homeDirectory}/nixos/config";
  nixos-fonts = "${config.home.homeDirectory}/nixos/fonts";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;

  # Define GNOME extensions
  myGnomeExtensions = with pkgs.gnomeExtensions; [
    run-or-raise
    gsconnect
    just-perfection
    power-tracker
    screen-brightness-governor
    shu-zhi
    window-is-ready-remover
    focused-window-d-bus
  ];
in {
  # ========================================
  # SOPS Configuration
  # ========================================
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets/ssh.yaml;
  };

  home.username = "marcin";
  home.homeDirectory = "/home/marcin";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # ========================================
  # IMPORTS - Additional modules
  # ========================================
  imports = [
    ../../modules/services/syncthing.nix
    ../../modules/services/ssh.nix
    ../../modules/services/ssh-askpass.nix
    ../../modules/utils/yazi.nix
    ../../modules/utils/neovim.nix
    ../../modules/home/tools/zoxide.nix
    ../../modules/home/tools/atuin.nix
    ../../modules/home/shell/bash.nix
    ../../modules/home/shell/starship.nix
    ../../modules/home/terminal/tmux.nix
  ];

  # ========================================
  # USER-SPECIFIC OVERRIDES
  # ========================================

  # Override Atuin server if needed (example)
  # programs.atuin.settings.sync_address = lib.mkForce "https://different-server.lan";

  # Add user-specific bash aliases
  programs.bash.shellAliases = {
    # Merges with default aliases from module
    myalias = "echo 'custom for marcin'";
  };

  # ========================================
  # GIT Configuration (FIXED - new syntax)
  # ========================================
  programs.git = {
    enable = true;

    # Use programs.git.settings instead of userEmail and userName
    settings = {
      user.name = "marcin";
      user.email = "nixosgitemail.frivolous320@passmail.net";
      init.defaultBranch = "main";
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };

  # ========================================
  # FONTS
  # ========================================
  fonts.fontconfig.enable = true;

  # ========================================
  # HOME FILE CONFIGURATION
  # ========================================
  home.file = {
    # Custom fonts for Emacs (Playpen Sans Hebrew for journal)
    ".local/share/fonts/custom" = {
      source = create_symlink nixos-fonts;
      recursive = true;
    };
  };

  # ========================================
  # HOME PACKAGES
  # ========================================
  home.packages = with pkgs;
    [
      # My custom packages
      customPkgs.rebuild-and-diff

      # GUI Applications
      blanket
      signal-desktop
      brave
      gnome-secrets

      # Productivity & Office
      libreoffice-fresh # Office suite
      zotero # Reference manager
      obsidian # Knowledge management

      # Media & Entertainment
      spotify # Music streaming
      spotify-player # Terminal Spotify client
      gnome-mahjongg

      # Emacs (simple installation - manages its own packages from ~/.emacs.d)
      emacs

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
      lsof
      procfd
      usbutils
      pciutils
      wget
      rclone
      rclone-ui

      # Nix tools
      nix-prefetch-github
      sops
      age
      nil
      nixpkgs-fmt
      nvd

      # File managers
      yazi

      # Fonts
      nerd-fonts.hack
      nerd-fonts.jetbrains-mono
      google-fonts
      liberation_ttf

      # Language tools (for Emacs spell/grammar checking)
      hunspell
      hunspellDicts.en_GB-large
      hunspellDicts.pl_PL
      languagetool
    ]
    ++ myGnomeExtensions; # Add GNOME extensions to packages

  # ========================================
  # ENVIRONMENT VARIABLES
  # ========================================
  home.sessionVariables = {
    LANGUAGETOOL_JAR = "${pkgs.languagetool}/share/languagetool-commandline.jar";
  };

  # ========================================
  # DCONF CONFIGURATION - CRITICAL!
  # ========================================

  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;

      # Automatically extract UUIDs from packages
      enabled-extensions = map (ext: ext.extensionUuid) myGnomeExtensions;

      # Explicitly empty the disabled list
      disabled-extensions = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
    };
    "org/gnome/settings-daemon/plugins/power" = {
      # Allow suspend even when external monitors connected
      lid-close-suspend-with-external-monitor = true;
    };
  };

  # Run-or-raise shortcuts (same as nix repo)
  xdg.configFile."run-or-raise/shortcuts.conf".text = ''
    <Control><Alt>e,${pkgs.emacs}/bin/emacs,emacs
    <Super>f,${pkgs.brave}/bin/brave,,
    <Super>e:always-run,nautilus,org.gnome.Nautilus
    <Super>t,ptyxis,org.gnome.Ptyxis
    <Control>p,${pkgs.signal-desktop}/bin/signal-desktop,signal
  '';
}
