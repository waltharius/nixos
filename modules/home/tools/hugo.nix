{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.programs.hugo;

  # Fetch Hugo Book theme from GitHub (cached in Nix store)
  hugo-book-theme = pkgs.fetchFromGitHub {
    owner = "alex-shpak";
    repo = "hugo-book";
    rev = "v13"; # Use specific version for reproducibility
    sha256 = "0000000000000000000000000000000000000000000000000000"; # Placeholder - see below
  };
in {
  options.programs.hugo = {
    enable = mkEnableOption "Hugo static site generator for documentation";

    siteDirectory = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/syncthing/hugo";
      description = "Directory where Hugo site is stored";
    };

    theme = mkOption {
      type = types.str;
      default = "hugo-book";
      description = "Hugo theme to use";
    };

    baseURL = mkOption {
      type = types.str;
      default = "http://localhost:1313";
      example = "https://docs.example.com";
      description = "Base URL for the Hugo site";
    };

    autoServe = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Automatically start Hugo server as systemd user service.
        Hugo server runs on localhost:1313, consumes ~100MB RAM.
      '';
    };

    servePort = mkOption {
      type = types.int;
      default = 1313;
      description = "Port for Hugo development server";
    };
  };

  config = mkIf cfg.enable {
    # Install Hugo from unstable channel
    home.packages = [
      pkgs-unstable.hugo
    ];

    # Create Hugo site directory structure
    home.file."${cfg.siteDirectory}/.keep".text = "";

    # Hugo configuration file
    home.file."${cfg.siteDirectory}/config.toml".text = ''
      baseURL = "${cfg.baseURL}"
      title = "Documentation"
      languageCode = "en-us"
      theme = "${cfg.theme}"

      [params]
        BookSearch = true
        BookToC = true
        BookMenuBundle = "menu"
        BookRepo = ""
        BookEditPath = ""

      [outputs]
        home = ["HTML", "RSS"]

      [markup]
        [markup.goldmark]
          [markup.goldmark.renderer]
            unsafe = true
        [markup.highlight]
          style = "monokai"
          lineNos = false

      [[menu.before]]
        name = "Documentation"
        url = "/docs"
        weight = 1
    '';

    # Create content directory with welcome page
    home.file."${cfg.siteDirectory}/content/docs/_index.md".text = ''
      ---
      title: "Documentation"
      type: docs
      bookToc: false
      ---

      # Welcome to Documentation

      All pages tagged with `:hugosync:` in your notes will appear here.

      This site is automatically generated from your Denote notes.
    '';

    # Symlink theme from Nix store (no download, no Git needed!)
    home.file."${cfg.siteDirectory}/themes/${cfg.theme}".source = hugo-book-theme;

    # Systemd user service for Hugo development server
    systemd.user.services.hugo-server = mkIf cfg.autoServe {
      Unit = {
        Description = "Hugo development server";
        After = ["graphical-session.target"];
      };

      Service = {
        Type = "simple";
        WorkingDirectory = cfg.siteDirectory;
        ExecStart = "${pkgs-unstable.hugo}/bin/hugo server --bind 127.0.0.1 --port ${toString cfg.servePort} --disableFastRender";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install = {
        WantedBy = ["default.target"];
      };
    };

    # Shell aliases for convenience
    home.shellAliases = {
      hugo-serve = "cd ${cfg.siteDirectory} && ${pkgs-unstable.hugo}/bin/hugo server";
      hugo-build = "cd ${cfg.siteDirectory} && ${pkgs-unstable.hugo}/bin/hugo";
      hugo-status = "systemctl --user status hugo-server";
      hugo-restart = "systemctl --user restart hugo-server";
      hugo-logs = "journalctl --user -u hugo-server -f";
    };
  };
}
