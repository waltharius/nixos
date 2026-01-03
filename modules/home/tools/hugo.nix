{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.programs.hugo;
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
        Hugo server runs on localhost only, consumes ~100MBAM.
        With 128GB RAM, this is negligible for convenience.
      '';
    };

    servePort = mkOption {
      type = types.int;
      default = 1313;
      description = "Port for Hugo development server";
    };
  };

  config = mkIf cfg.enable {
    # Install Hugo package
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
        BookRepo = ""  # No public repo
        BookEditPath = ""  # No edit links

      [outputs]
        home = ["HTML", "RSS"]

      [markup]
        [markup.goldmark]
          [markup.goldmark.renderer]
            unsafe = true  # Allow HTML in markdown
        [markup.highlight]
          style = "monokai"
          lineNos = false

      [[menu.before]]
        name = "Documentation"
        url = "/docs"
        weight = 1
    '';

    # Create content directory structure with example page
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

    # Systemd user service for Hugo development server (optional)
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
    };

    # Download theme on first activation (safer than in config)
    home.activation.hugoTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
      THEME_DIR="${cfg.siteDirectory}/themes/${cfg.theme}"
      if [ ! -d "$THEME_DIR" ]; then
        $DRY_RUN_CMD mkdir -p "${cfg.siteDirectory}/themes"
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone https://github.com/alex-shpak/hugo-book "$THEME_DIR" --depth 1
        echo "Downloaded Hugo theme: ${cfg.theme}"
      fi
    '';
  };
}
