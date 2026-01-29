# ./modules/system/brave.nix
# Module for system-wide Brave configuration for all users
# Brave is from "unstable" branch.
# It has support for Polish language
# More policies descriptions can be find at https://chromeenterprise.google/policies/
{pkgs-unstable, ...}: {
  programs.chromium = {
    enable = true;

    # Chromium policies applyied tto Brave
    extraOpts = {
      # Enable spellcheck
      "SpellcheckEnabled" = true;

      # Language to check spelling for
      "SpellcheckLanguage" = [
        "en-US"
        "pl"
      ];

      # Configure the content and order of preferred languages
      "ForcedLanguages" = [
        "en-US"
        "pl"
      ];

      # Disable automatic page translation prompt
      # This prevents "Translate this page?" pupups
      "TranslateEnabled" = false;

      # Default Search Engine
      "DefaultSearchProviderEnabled" = true;
      "DefaultSearchProviderName" = "Ecosia";
      "DefaultSearchProviderKeyword" = "ec";
      "DefaultSearchProviderSearchURL" = "https://ecosia.org/search?q={searchTerms}";
      "DefaultSearchProviderSuggestURL" = "https://ac.ecosia.org/autocomplete?q={searchTerms}";
      "DefaultSearchProviderIconURL" = "https://www.ecosia.org/favicon.ico";

      # Diable Leo AI Assistant
      # Note: This hides Leo but Brave may not have a complete policy yet
      # You may need to manually disable it in brave://settings/leo-ai
      "BraveAIChatEnabled" = false;

      # Privacy & Security stuff
      "MetricsReportingEnabled" = false;
      "BrowserGuestModeEnabled" = false;

      # UI/UX
      "BookmarkBarEnabled" = true;
    };
  };

  # Install Brave system-wide
  environment.systemPackages = [pkgs-unstable.brave];
}
