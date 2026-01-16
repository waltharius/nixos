# users/marcin/apps.nix
# Marcin's personal applications (used with "regular" role)
# Preserves your exact package selection from home.nix
{
  pkgs,
  customPkgs ? {},
  ...
}: {
  home.packages = with pkgs; [
    # ==========================================
    # Custom packages (yours)
    # ==========================================
    customPkgs.rebuild-and-diff
    customPkgs.solaar-stable
    customPkgs.track-package
    customPkgs.track-package-deps
    customPkgs.track-package-py
    customPkgs.track-package-simple

    # ==========================================
    # GUI Applications
    # ==========================================
    blanket
    signal-desktop
    brave
    gnome-secrets
    vivaldi
    shotwell
    nextcloud-client

    # ==========================================
    # Productivity & Office
    # ==========================================
    libreoffice-fresh
    zotero
    obsidian
    thunderbird-latest

    # ==========================================
    # Media & Entertainment
    # ==========================================
    spotify
    spotify-player
    gnome-mahjongg
    gnome-podcasts

    # ==========================================
    # Development
    # ==========================================
    emacs

    # ==========================================
    # Fonts (you need these everywhere)
    # ==========================================
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
    google-fonts
    liberation_ttf

    # ==========================================
    # Language tools (for Emacs spell/grammar checking)
    # ==========================================
    hunspell
    hunspellDicts.en_GB-large
    hunspellDicts.pl_PL
    languagetool
  ];

  # Environment variables for apps
  home.sessionVariables = {
    LANGUAGETOOL_JAR = "${pkgs.languagetool}/share/languagetool-commandline.jar";
  };

  # ==========================================
  # Nextcloud Client config (your existing)
  # ==========================================
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
}
