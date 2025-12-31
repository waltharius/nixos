{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;

    settings = {
      # Your self-hosted server
      sync_address = "https://atuin.home.lan";
      auto_sync = false; # Using atuin-daemon for syncing in the bacground

      sync = {
        records = true;
      };

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
}
