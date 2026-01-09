# Atuin shell history with server sync for containers/servers
{pkgs, ...}: {
  # Install atuin system-wide
  environment.systemPackages = with pkgs; [atuin];

  # Configure atuin system-wide
  environment.etc."atuin/config.toml".text = ''
    # Atuin server sync configuration

    ## Your self-hosted Atuin server
    sync_address = "https://atuin.home.lan"

    ## Auto-sync settings
    auto_sync = true
    sync_frequency = "300"

    ## Search settings
    search_mode = "fuzzy"
    filter_mode = "host"
    style = "compact"
    show_preview = true

    ## Smart Up arrow - filter by directory
    filter_mode_shell_up_key_binding = "directory"

    ## Privacy - never save sensitive commands
    history_filter = [
      "^pass",
      "^password",
      "^secret",
      "^atuin login",
      "^atuin register",
      "^export.*KEY",
      "^export.*SECRET",
      "^export.*TOKEN",
      "^sudo.*password",
    ]

    ## Update shell history
    update_snapshots = true

    ## Sync records (command history + metadata)
    sync.records = true
  '';

  # CRITICAL: Enable bash system-wide
  programs.bash = {
    # Enable bash completion and integration
    enableCompletion = true;

    # This is CRITICAL - it creates /etc/bashrc
    enableLsColors = true;

    # Add Atuin integration
    promptInit = ''
      # Atuin shell history initialization
      if command -v atuin &> /dev/null; then
        export ATUIN_CONFIG_DIR="/etc/atuin"
        export ATUIN_NOBIND="true"  # Don't bind keys yet
        eval "$(${pkgs.atuin}/bin/atuin init bash)"
      fi
    '';

    # Interactive shell init (runs after promptInit)
    interactiveShellInit = ''
      # Bind Ctrl+R to Atuin search
      if command -v atuin &> /dev/null; then
        bind -x '"\C-r": __atuin_history'

        # Optional: Bind up arrow for directory-filtered history
        bind '"\e[A": __atuin_history --shell-up-key-binding'
      fi
    '';
  };

  # Create systemd timer for background sync
  systemd.timers.atuin-sync = {
    description = "Atuin History Sync Timer";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
    };
  };

  systemd.services.atuin-sync = {
    description = "Atuin History Sync";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.atuin}/bin/atuin sync";
      User = "root";
    };
    environment = {
      ATUIN_CONFIG_DIR = "/etc/atuin";
    };
  };
}
