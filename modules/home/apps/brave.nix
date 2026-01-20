{
  config,
  pkgs,
  pkgs-unstable,
  ...
}: {
  programs.chromium = {
    enable = true;
    package = pkgs-unstable.brave; # If not explicitely stated Chromium will be installed

    # Chromium policiec applyied tto Brave
    extraOpts = {
      # Set browser UI language to English
      "ApplicationLocaleValue" = "en";

      # Languages list for content (first on list is default)
      # Affects: Site's content language preferences, HTTP Accept-Language header
      "AcceptLanguages" = "en-US,en, pl";

      # Enable spellcheck
      "SpellcheckEnable" = true;

      # Language to check spelling for
      "SpellcheckLanguage" = [
        "en-US"
        "pl"
      ];

      # Disable automatic page translation prompt
      # This prevents "Translate this page?" pupups
      "TranslateEnables" = false;

      # Default Search Engine
      "DefaultSearchProviderEnabled" = true;
      "DefaultSearchProviderName" = "DuckDuckGo";
      "DefaultSearchProviderKeyword" = "ddg";
      "DefaultSearchProviderSearchURL" = "https://duckduckgo.com/?q={searchTerms}";
      "DefaultSearchProviderSuggestURL" = "https://duckduckgo.com/ac/?q={searchTerms}&type=list";

      # Diable Leo AI Assistant
      # Note: This hides Leo but Brave may not have a complete policy yet
      # You may need to manually disable it in brave://settings/leo-ai
      "BraveAIChatEnabled" = false;

      # Wide address bar
      "BraveWideAddressBarEnabled" = true;

      # Privacy & Security stuff
      "MetricsReportingEnabled" = false;

      # UI/UX
      "BookmarkBarEnabled" = true;
      "DownloadDirectory" = "${config.homeDirectory}/Downloads";
    };
  };

  # Install spellcheck dictionaries (it might be duplicated by home.nix or flake.nix)
  home.packages = with pkgs; [
    hunspellDicts.en_US
    hunspellDicts.pl_PL
  ];
}
