{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.programs.hugo;

  # ============================================================
  # THEME CONFIGURATION - Easy to modify!
  # ============================================================

  themeConfig = {
    owner = "h-enk";
    repo = "doks";
    rev = "v0.5.1";
    sha256 = "sha256-r2KfmWK7BC7LjnZVvwb2Mbqnd8a6Q32fBqiQfZTpGy4=";
    name = "doks";
  };

  # ============================================================
  # SITE CONFIGURATION
  # ============================================================

  siteConfig = {
    title = "Documentation";
    description = "Documentation site built with Hugo and Doks";
    languageCode = "en-us";
    author = "Marcin";
    footer = "Made with Hugo and Doks";
  };

  # ============================================================
  # FETCH THEME
  # ============================================================

  hugo-theme = pkgs.fetchFromGitHub {
    owner = themeConfig.owner;
    repo = themeConfig.repo;
    rev = themeConfig.rev;
    sha256 = themeConfig.sha256;
  };

  # ============================================================
  # CONFIG.TOML CONTENT
  # ============================================================

  configToml = ''
    baseURL = "${cfg.baseURL}"
    title = "${siteConfig.title}"
    theme = "${themeConfig.name}"
    languageCode = "${siteConfig.languageCode}"

    [taxonomies]
      tag = "tags"

    [markup]
      [markup.goldmark]
        [markup.goldmark.renderer]
          unsafe = true
      [markup.highlight]
        style = "monokai"

    [[menu.main]]
      name = "Documentation"
      url = "/docs/"
      weight = 10

    [[menu.main]]
      name = "Tags"
      url = "/tags/"
      weight = 20

    [params]
      description = "${siteConfig.description}"
      author = "${siteConfig.author}"
  '';
in {
  options.programs.hugo = {
    enable = mkEnableOption "Hugo static site generator";

    siteDirectory = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/syncthing/hugo";
      description = "Hugo site directory";
    };

    baseURL = mkOption {
      type = types.str;
      default = "http://localhost:1313";
      description = "Base URL for Hugo site";
    };

    autoServe = mkOption {
      type = types.bool;
      default = true;
      description = "Auto-start Hugo server";
    };

    servePort = mkOption {
      type = types.int;
      default = 1313;
      description = "Hugo server port";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs-unstable.hugo];

    home.file."${cfg.siteDirectory}/.keep".text = "";

    home.file."${cfg.siteDirectory}/config.toml".text = configToml;

    home.file."${cfg.siteDirectory}/content/docs/_index.md".text = ''
      ---
      title: "Documentation"
      description: "Welcome to the documentation"
      draft: false
      ---

      # Welcome to Documentation

      This site is automatically generated from your Denote notes.
    '';

    home.file."${cfg.siteDirectory}/themes/${themeConfig.name}".source = hugo-theme;

    systemd.user.services.hugo-server = mkIf cfg.autoServe {
      Unit = {
        Description = "Hugo development server";
        After = ["graphical-session.target"];
      };

      Service = {
        Type = "simple";
        WorkingDirectory = cfg.siteDirectory;
        ExecStart = "${pkgs-unstable.hugo}/bin/hugo server --bind 127.0.0.1 --port ${toString cfg.servePort}";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install = {
        WantedBy = ["default.target"];
      };
    };

    home.shellAliases = {
      hugo-serve = "cd ${cfg.siteDirectory} && ${pkgs-unstable.hugo}/bin/hugo server";
      hugo-build = "cd ${cfg.siteDirectory} && ${pkgs-unstable.hugo}/bin/hugo";
      hugo-status = "systemctl --user status hugo-server";
      hugo-restart = "systemctl --user restart hugo-server";
      hugo-logs = "journalctl --user -u hugo-server -f";
    };
  };
}
