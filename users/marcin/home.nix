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
  ];

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

  # ==:wifi======================================
  # TMUX Configuration
  # ========================================
  programs.tmux = {
    enable = true;
    mouse = true;
    escapeTime = 0;
    historyLimit = 1000000;
    baseIndex = 1;
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '5'
        '';
      }
    ];
  };

  # ========================================
  # BASH Configuration
  # ========================================
  programs.bash = {
    enable = true;

    shellAliases = {
      # Enhanced ls with eza
      ls = "eza --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git";
      ll = "eza -alF --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git";
      la = "eza -a --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git";
      lt = "eza --tree --hyperlink --group-directories-first --color=auto --icons --git";

      # Git shortcuts
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";

      # NixOS shortcuts
      nrs = "rebuild-and-diff";
      nrt = "sudo nixos-rebuild test --flake ~/nixos#$(hostname)";
      nrb = "sudo nixos-rebuild boot --flake ~/nixos#$(hostname)";

      # WiFi management (NetworkManager)
      wifi-list = "nmcli device wifi list";
      wifi-connect = "nmcli device wifi connect";
      wifi-status = "nmcli connection show --active";
      wifi-forget = "nmcli connection delete";
      wifi-scan = "nmcli device wifi rescan";

      # Atuin filter modes
      atuin-local = "ATUIN_FILTER_MODE=host atuin search -i";
      atuin-global = "ATUIN_FILTER_MODE=global atuin search -i";
    };

    bashrcExtra = ''

      # Load ble.sh if available
      if [[ -f ${pkgs.blesh}/share/blesh/ble.sh ]]; then
        source ${pkgs.blesh}/share/blesh/ble.sh --noattach
      fi

      eval "$(starship init bash)"

      # Atuin integration
      if command -v atuin &> /dev/null; then
        eval "$(${pkgs.atuin}/bin/atuin init bash)"
      fi

      # Zoxide integration
      if command -v zoxide &> /dev/null; then
        eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
      fi

      # Attach ble.sh after integrations
      [[ ''${BLE_VERSION-} ]] && ble-attach || true

      # Yazi shell wrapper for cd on exit
      if command -v yazi &> /dev/null; then
        function y() {
          local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
          yazi "$@" --cwd-file="$tmp"
          if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
          fi
          rm -f -- "$tmp"
        }
      fi
    '';
  };

  # ========================================
  # STARSHIP - Cross-shell Prompt
  # ========================================
  programs.starship = {
    enable = true;
    enableBashIntegration = true;

    settings = {
      add_newline = false;

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };

      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
        style = "bold cyan";
      };

      git_branch = {
        symbol = "";
        style = "bold purple";
      };

      nix_shell = {
        symbol = " ";
        format = "[$symbol$state( ($name))]($style) ";
        style = "bold blue";
      };
    };
  };

  # ========================================
  # ZOXIDE - Smarter cd
  # ========================================
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    options = ["--cmd cd"];
  };

  # ========================================
  # ATUIN - Shell History Sync
  # ========================================
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;

    settings = {
      # Your self-hosted server
      sync_address = "https://atuin.home.lan";
      auto_sync = false;

      daemon = {
        enabled = true;
        sync_frequency = 300;
      };

      # Filter by host by default
      filter_mode = "host";

      # Search settings
      search_mode = "fuzzy";
      style = "compact";
      show_preview = true;

      # Smart Up arrow - filter by directory
      filter_mode_shell_up_key_binding = "directory";

      # Privacy - never save sensitive commands
      history_filter = [
        "^pass"
        "^password"
        "^secret"
        "^atuin login"
      ];
    };
  };

  systemd.user.services = {
    atuin-daemon = {
      Unit = {
        Description = "Atuin Shell History Daemon";
        After = ["grpahical-session.target"];
      };

      Service = {
        ExecStart = "${pkgs.atuin}/bin/atuin daemon";
        Restart = "on-failure";
      };

      Install = {
        WantedBy = ["default.target"];
      };
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
