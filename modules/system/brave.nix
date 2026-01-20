# ./modules/system/brave.nix
# Module for system-wide Brave configuration for all users
# Brave is from "unstable" branch.
# It has support for Polish language
{pkgs-unstable, ...}: {
  programs.chromium = {
    enable = true;

    # Chromium policiec applyied tto Brave
    extraOpts = {
      # Enable spellcheck
      "SpellcheckEnabled" = true;

      # Language to check spelling for
      "SpellcheckLanguage" = [
        "en-US"
        "pl"
      ];

      # Disable automatic page translation prompt
      # This prevents "Translate this page?" pupups
      "TranslateEnabled" = false;

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

      # Privacy & Security stuff
      "MetricsReportingEnabled" = false;

      # UI/UX
      "BookmarkBarEnabled" = true;
    };
  };

  # Install Brave system-wide
  environment.systemPackages = [pkgs-unstable.brave];
}
