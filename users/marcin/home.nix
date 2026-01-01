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
    customPkgs.solaar-extension
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
      customPkgs.solaar-stable

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

  xdg.configFile."solaar/rules.yaml".text = ''
    %YAML 1.3
    ---
    # 1. Thumb Wheel Zoom
    - Rule:
        - Key: Thumb Wheel Up
        - KeyPress:
          - Control_L
          - Equal
    - Rule:
        - Key: Thumb Wheel Down
        - KeyPress:
          - Control_L
          - Equal

    # 2. Gesture Button Actions
    - Rule:
        - Key: Mouse Gesture Button
        - Divert: true # Important: stops the button from just clicking immediately

    # 2a. Move Left -> Workspace Left (Super + Alt + Left)
    - Rule:
        - Test: [Mouse Gesture Button, Pressed]
        - Key: Mouse Left
        - KeyVPress:
          - Super_L
          - Alt_L
          - Left

    # 2b. Move Right -> Workspace Right (Super + Alt + Right)
    - Rule:
        - Test: [Mouse Gesture Button, Pressed]
        - Key: Mouse Right
        - KeyVPress:
          - Super_L
          - Alt_L
          - Right

    # 2c. Simple Click -> Overview (Super)
    # This fires if you release the button without moving
    - Rule:
        - Key: Mouse Gesture Button
        - KeyPress: Super_L
    ...
  '';

  xdg.configFile."solaar/config.yaml".text = ''
    %YAML 1.3
    ---
    - _NAME: MX Keys S
      _battery: 0
      _modelId: B37800000000
      _serial: B3177D71
      _unitId: B3177D71
      _wpid: B378
      backlight: 1
      backlight-timed: true
      divert-keys: {10: 0, 111: 0, 199: 0, 200: 0, 226: 0, 227: 0, 228: 0, 229: 0, 230: 0, 231: 0, 232: 0, 233: 0, 234: 0, 259: 0, 264: 0, 266: 0, 284: 0}
      fn-swap: true
    - _NAME: MX Master 3S
      _battery: 0
      _modelId: B03400000000
      _serial: 01777DA3
      _unitId: 01777DA3
      _wpid: B034
      dpi: 1000
      smart-shift: 10
      thumb-scroll-invert: false
      thumb-scroll-mode: true
      # To jest kluczowe! Włączamy divert dla przycisków
      divert-keys: {82: 0, 83: 0, 86: 0, 195: 0, 196: 0}
      reprogrammable-keys: {80: 80, 81: 81, 82: 82, 83: 83, 86: 86, 195: 195, 196: 196}
  '';

  # Autostart applications after first loging to Gnome
  xdg.configFile."autostart/signal-desktop.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Signal
    Exec=${pkgs.signal-desktop}/bin/signal-desktop
    Terminal=false
  '';
  xdg.configFile."autostart/ptyxis.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Ptyxis
    Exec=${pkgs.ptyxis}/bin/ptyxis
  '';
  xdg.configFile."autostart/solaar.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Solaar
    Exec=solaar --window=hide
    Icon=solaar
    StartupNotify=false
    NoDisplay=true
  '';
}
