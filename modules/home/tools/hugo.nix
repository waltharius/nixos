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
    # Change these values to switch themes
    owner = "h-enk"; # GitHub owner
    repo = "doks"; # Repository name
    rev = "v0.5.1"; # Version/tag/commit
    sha256 = "sha256-r2KfmWK7BC7LjnZVvwb2Mbqnd8a6Q32fBqiQfZTpGy4="; # Hash
    name = "doks"; # Theme directory name
  };

  # ============================================================
  # SITE CONFIGURATION - Customize your site
  # ============================================================

  siteConfig = {
    title = "Documentation";
    description = "Documentation site built with Hugo and Doks";
    languageCode = "en-us";
    defaultContentLanguage = "en";

    # Author and copyright
    author = "Marcin";
    footer = "Made with Hugo and Doks";

    # Features
    enableGitInfo = false;
    enableRobotsTXT = true;
    canonifyURLs = true;

    # Display options
    displayTags = true;
    darkMode = true;
    searchEnabled = true;
    tocEnabled = true;
  };

  # ============================================================
  # MARKUP CONFIGURATION
  # ============================================================

  markupConfig = {
    # Syntax highlighting
    highlightStyle = "monokai"; # Options: monokai, dracula, github, etc.
    lineNumbers = true;
    lineNumbersInTable = true;

    # Markdown rendering
    unsafeHTML = true; # Allow HTML in markdown
  };

  # ============================================================
  # MENU CONFIGURATION
  # ============================================================

  menuItems = [
    {
      name = "Documentation";
      url = "/docs/";
      weight = 10;
    }
    {
      name = "Tags";
      url = "/tags/";
      weight = 20;
    }
  ];

  # ============================================================
  # FETCH THEME FROM GITHUB
  # ============================================================

  hugo-theme = pkgs.fetchFromGitHub {
    owner = themeConfig.owner;
    repo = themeConfig.repo;
    rev = themeConfig.rev;
    sha256 = themeConfig.sha256;
  };

  # ============================================================
  # GENERATE CONFIG.TOML CONTENT
  # ============================================================

  configToml = ''
    baseURL = "${cfg.baseURL}"
    title = "${siteConfig.title}"
    theme = "${themeConfig.name}"

    # Language settings
    languageCode = "${siteConfig.languageCode}"
    defaultContentLanguage = "${siteConfig.defaultContentLanguage}"

    # Hugo settings
    enableGitInfo = ${boolToString siteConfig.enableGitInfo}
    enableRobotsTXT = ${boolToString siteConfig.enableRobotsTXT}
    canonifyURLs = ${boolToString siteConfig.canonifyURLs}
    disableAliases = true
    disableHugoGeneratorInject = true

    # Taxonomies (for tags and categories)
    [taxonomies]
      tag = "tags"
      category = "categories"

    # Markup settings
    [markup]
      [markup.goldmark]
        [markup.goldmark.renderer]
          unsafe = ${boolToString markupConfig.unsafeHTML}
      [markup.highlight]
        style = "${markupConfig.highlightStyle}"
        lineNos = ${boolToString markupConfig.lineNumbers}
        lineNumbersInTable = ${boolToString markupConfig.lineNumbersInTable}

    # Output formats
    [outputs]
      home = ["HTML", "RSS"]
      section = ["HTML", "RSS"]
      taxonomy = ["HTML"]
      term = ["HTML"]

    ${concatMapStrings (item: ''
        [[menu.main]]
          name = "${item.name}"
          url = "${item.url}"
          weight = ${toString item.weight}

      '')
      menuItems}

    # Theme-specific parameters
    [params]
      description = "${siteConfig.description}"
      author = "${siteConfig.author}"
      footer = "${siteConfig.footer}"

      # Display options
      displayTags = ${boolToString siteConfig.displayTags}

      # Doks-specific options
      ${optionalString (themeConfig.name == "doks") ''
      options.lazySizes = true
      options.clipBoard = true
      options.instantPage = true
      options.flexSearch = ${boolToString siteConfig.searchEnabled}
      options.darkMode = ${boolToString siteConfig.darkMode}
    ''}

      # Hugo-book-specific options
      ${optionalString (themeConfig.name == "hugo-book") ''
      BookSearch = ${boolToString siteConfig.searchEnabled}
      BookToC = ${boolToString siteConfig.tocEnabled}
      BookTagCloud = ${boolToString siteConfig.displayTags}
      BookDisplayTags = ${boolToString siteConfig.displayTags}
      BookMenuBundle = "menu"
      BookRepo = ""
      BookEditPath = ""
    ''}
  '';

  # ============================================================
  # WELCOME PAGE CONTENT
  # ============================================================

  welcomePageContent = ''
    ---
    title: "${siteConfig.title}"
    description: "${siteConfig.description}"
    lead: "All pages tagged with :hugosync: appear here"
    date: 2026-01-03T00:00:00+00:00
    lastmod: 2026-01-03T00:00:00+00:00
    draft: false
    weight: 50
    toc: false
    ---

    # Welcome to ${siteConfig.title}

    This site is automatically generated from your Denote notes.

    ## Features

    - 📝 Automatic sync from Emacs Denote notes
    - 🏷️ Tag-based organization
    - 🔍 Full-text search
    ${optionalString siteConfig.darkMode "- 🌙 Dark mode support"}
    - ⚡ Fast static site generation
  '';
in {
  # ============================================================
  # MODULE OPTIONS
  # ============================================================

  options.programs.hugo = {
    enable = mkEnableOption "Hugo static site generator for documentation";

    siteDirectory = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/syncthing/hugo";
      description = "Directory where Hugo site is stored";
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
        Hugo server runs on localhost, consumes ~100MB RAM.
      '';
    };

    servePort = mkOption {
      type = types.int;
      default = 1313;
      description = "Port for Hugo development server";
    };
  };

  # ============================================================
  # MODULE CONFIGURATION
  # ============================================================

  config = mkIf cfg.enable {
    # Install Hugo from unstable channel (latest version)
    home.packages = [
      pkgs-unstable.hugo
    ];

    # Create Hugo site directory structure
    home.file."${cfg.siteDirectory}/.keep".text = "";

    # Generate Hugo configuration file
    home.file."${cfg.siteDirectory}/config.toml".text = configToml;

    # Create content directory with welcome page
    home.file."${cfg.siteDirectory}/content/docs/_index.md".text = welcomePageContent;

    # Symlink theme from Nix store (immutable, cached)
    home.file."${cfg.siteDirectory}/themes/${themeConfig.name}".source = hugo-theme;

    # Systemd user service for Hugo development server
    systemd.user.services.hugo-server = mkIf cfg.autoServe {
      Unit = {
        Description = "Hugo development server for ${siteConfig.title}";
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
      hugo-stop = "systemctl --user stop hugo-server";
      hugo-start = "systemctl --user start hugo-server";
      hugo-logs = "journalctl --user -u hugo-server -f";
      hugo-clean = "cd ${cfg.siteDirectory} && rm -rf public resources";
    };
  };
}
