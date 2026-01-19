# Home Manager configuration for user marcin
# Combines configuration from both previous setups
{
  config,
  pkgs,
  lib,
  customPkgs ? {}, # Optional with empty default
  pkgs-unstable,
  ...
}: let
  # Dotfiles symlink helper
  # dotfiles = "${config.home.homeDirectory}/nixos/config";
  nixos-fonts = "${config.home.homeDirectory}/nixos/fonts";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;

  # Define GNOME extensions
  myGnomeExtensions = with pkgs.gnomeExtensions; [
    appindicator
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
    ../../modules/utils/nixvim
    ../../modules/home/tools/zoxide.nix
    ../../modules/home/tools/atuin.nix
    ../../modules/home/shell/bash.nix
    ../../modules/home/shell/starship.nix
    ../../modules/home/terminal/tmux.nix
    #    ../../modules/home/tools/hugo.nix
    ../../modules/home/tools/buku.nix
  ];

  #  programs.hugo = {
  #    enable = true;
  #    baseURL = "http://localhost:1313";
  #  };
  #
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
  # Nextcloud Client config
  # ========================================
  # Declarative sync exclusions
  xdg.configFile."Nextcloud/sync-exclude.lst" = {
    text = ''
      *.part
      .~lock.*
      ~$*
      .*.sw?
      .*~
      Desktop.ini
      Thumbs.db
      .dropbox
      .dropbox.attr

      .stfolder
      .stignore
      .stversions/

      .stfolder/
      .stversions/
      */.stfolder
      */.stignore
      */.stversions/

      .git/
      */.git/
      *.orig
      *.rej
      .git/index.lock

      node_modules/
      */node_modules/
      __pycache__/
      */__pycache__/
      .pytest_cache/
      */.pytest_cache/
      target/
      */target/
      build/
      */build/
      dist/
      */dist/

      *.tmp
      *.temp
      *.log
      .DS_Store
    '';
  };

  # ========================================
  # HOME PACKAGES
  # ========================================
  home.packages = with pkgs;
    [
      # My custom packages
      customPkgs.rebuild-and-diff
      customPkgs.solaar-stable
      customPkgs.track-package
      customPkgs.track-package-deps
      customPkgs.track-package-py
      customPkgs.track-package-simple

      # GUI Applications
      blanket
      signal-desktop
      brave
      gnome-secrets
      vivaldi
      shotwell
      nextcloud-client

      # Productivity & Office
      libreoffice-fresh # Office suite
      zotero # Reference manager
      obsidian # Knowledge management
      thunderbird-latest

      # Media & Entertainment
      spotify # Music streaming
      spotify-player # Terminal Spotify client
      gnome-mahjongg
      gnome-podcasts

      # Emacs (simple installation - manages its own packages from ~/.emacs.d)
      # NOTE: doom-emacs is installed via programs.doom-emacs module
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
    <Super>e,nautilus,org.gnome.Nautilus
    <Super>t,ptyxis,org.gnome.Ptyxis
    <Control>p,${pkgs.signal-desktop}/bin/signal-desktop,signal
  '';

  xdg.configFile."solaar/rules.yaml".text = ''
    %YAML 1.3
    ---
    # Rule 1: Zoom In using Thumb Wheel Up
    # Condition: Thumb wheel moved up -> Action: Ctrl + equal
    - Feature: THUMB WHEEL
    - Rule:
      - Test: [thumb_wheel_up, 6]
      - KeyPress:
        - Control_L
        - equal
    ...
    ---
    # Rule 2: Zoom Out using Thumb Wheel Down
    # Condition: Thumb wheel moved down -> Action: Ctrl + minus
    - Feature: THUMB WHEEL
    - Rule:
      - Test: [thumb_wheel_down, 6]
      - KeyPress:
        - Control_L
        - minus
    ...
    ---
    # Rule 3: Mouse Gesture - Move Left (Workspace Switch)
    # Trigger: Gesture Button held + Mouse moved Left
    - MouseGesture: Mouse Left
    - KeyPress:
      - Super_L
      - Alt_L
      - Left
    ...
    ---
    # Rule 4: Mouse Gesture - Move Right (Workspace Switch)
    # Trigger: Gesture Button held + Mouse moved Right
    - MouseGesture: Mouse Right
    - KeyPress:
      - Super_L
      - Alt_L
      - Right
    ...
    ---
    # Rule 5: Simple Click on Gesture Button -> Overview
    # Trigger: Button pressed and released without movement
    # We check for the 'released' action to avoid repeats
    - Key: [Mouse Gesture Button, released]
    - KeyPress: Super_L
    ...
  '';

  xdg.configFile."solaar/config.yaml".text = ''
    %YAML 1.3
    ---
    - _NAME: MX Keys S
      _absent: [hi-res-scroll, lowres-scroll-mode, hires-smooth-invert, hires-smooth-resolution, hires-scroll-mode, scroll-ratchet, scroll-ratchet-torque, smart-shift,
        thumb-scroll-invert, thumb-scroll-mode, onboard_profiles, report_rate, report_rate_extended, pointer_speed, dpi, dpi_extended, speed-change, backlight-timed,
        led_control, led_zone_, rgb_control, rgb_zone_, brightness_control, per-key-lighting, reprogrammable-keys, persistent-remappable-keys, force-sensing,
        crown-smooth, divert-crown, divert-gkeys, m-key-leds, mr-key-led, gesture2-gestures, gesture2-divert, gesture2-params, haptic-level, haptic-play, sidetone,
        equalizer, adc_power_management]
      _battery: 4100
      _modelId: B37800000000
      _sensitive: {hires-scroll-mode: ignore, hires-smooth-invert: ignore, hires-smooth-resolution: ignore}
      _serial: B3177D71
      _unitId: B3177D71
      _wpid: B378
      backlight: 1
      backlight_duration_hands_in: 30
      backlight_duration_hands_out: 30
      backlight_duration_powered: 300
      backlight_level: 2
      change-host: null
      disable-keyboard-keys: {1: false, 2: false, 4: false, 8: false, 16: false}
      divert-keys: {10: 0, 111: 0, 199: 0, 200: 0, 226: 0, 227: 0, 228: 0, 229: 0, 230: 0, 231: 0, 232: 0, 233: 0, 234: 0, 259: 0, 264: 0, 266: 0, 284: 0}
      fn-swap: true
      multiplatform: 0
    - _NAME: MX Master 3S
      _absent: [hi-res-scroll, lowres-scroll-mode, scroll-ratchet-torque, onboard_profiles, report_rate, report_rate_extended, pointer_speed, dpi_extended,
        speed-change, backlight, backlight_level, backlight_duration_hands_out, backlight_duration_hands_in, backlight_duration_powered, backlight-timed, led_control,
        led_zone_, rgb_control, rgb_zone_, brightness_control, per-key-lighting, fn-swap, persistent-remappable-keys, disable-keyboard-keys, force-sensing,
        crown-smooth, divert-crown, divert-gkeys, m-key-leds, mr-key-led, multiplatform, gesture2-gestures, gesture2-divert, gesture2-params, haptic-level,
        haptic-play, sidetone, equalizer, adc_power_management]
      _battery: 4100
      _modelId: B03400000000
      _sensitive: {divert-keys: true, hires-scroll-mode: ignore, hires-smooth-invert: ignore, hires-smooth-resolution: ignore}
      _serial: 01777DA3
      _unitId: 01777DA3
      _wpid: B034
      change-host: null
      divert-keys: {82: 0, 83: 0, 86: 0, 195: 2, 196: 0}
      dpi: 1000
      hires-scroll-mode: false
      hires-smooth-invert: false
      hires-smooth-resolution: false
      reprogrammable-keys: {80: 80, 81: 81, 82: 82, 83: 83, 86: 86, 195: 195, 196: 196}
      scroll-ratchet: 2
      smart-shift: 10
      thumb-scroll-invert: false
      thumb-scroll-mode: true
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
