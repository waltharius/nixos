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
  # THEME CONFIGURATION - Use hugo-book (proven working)
  # ============================================================

  themeConfig = {
    owner = "alex-shpak";
    repo = "hugo-book";
    rev = "main"; # Use master branch (always works)
    sha256 = "sha256-7NihgHzoxtlDClzNZQIMj9vbN56nHeZylDi7TTnRXSo="; # Leave empty, we'll use fetchGit instead
    name = "hugo-book";
  };

  # ============================================================
  # SITE CONFIGURATION
  # ============================================================

  siteConfig = {
    title = "Documentation";
    description = "Documentation site";
    languageCode = "en-us";
  };

  # ============================================================
  # FETCH THEME - Use fetchGit (more reliable)
  # ============================================================

  hugo-theme = pkgs.fetchgit {
    url = "https://github.com/${themeConfig.owner}/${themeConfig.repo}";
    rev = "refs/heads/${themeConfig.rev}";
    sha256 = themeConfig.sha256;
  };
in {
  options.programs.hugo = {
    enable = mkEnableOption "Hugo static site generator";

    siteDirectory = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/syncthing/hugo";
    };

    baseURL = mkOption {
      type = types.str;
      default = "http://localhost:1313";
    };

    autoServe = mkOption {
      type = types.bool;
      default = true;
    };

    servePort = mkOption {
      type = types.int;
      default = 1313;
    };
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs-unstable.hugo];

    home.file."${cfg.siteDirectory}/config.toml".text = ''
      baseURL = "${cfg.baseURL}"
      title = "${siteConfig.title}"
      theme = "${themeConfig.name}"
      languageCode = "${siteConfig.languageCode}"

      [taxonomies]
        tag = "tags"

      [params]
        BookSearch = true
        BookToC = true
        BookDisplayTags = true

      [markup]
        [markup.goldmark]
          [markup.goldmark.renderer]
            unsafe = true
        [markup.highlight]
          style = "monokai"

      [[menu.before]]
        name = "Documentation"
        url = "/docs"
        weight = 1

      [[menu.before]]
        name = "Tags"
        url = "/tags"
        weight = 2
    '';

    home.file."${cfg.siteDirectory}/content/docs/_index.md".text = ''
      ---
      title: "Documentation"
      ---

      # Welcome

      Your documentation notes appear here.
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
      hugo-serve = "cd ${cfg.siteDirectory} && hugo server";
      hugo-status = "systemctl --user status hugo-server";
      hugo-restart = "systemctl --user restart hugo-server";
    };
  };
}
