# Atuin shell history with server sync for containers/servers
{pkgs, ...}: {
  # Install atuin system-wide
  environment.systemPackages = with pkgs; [atuin];

  # Configure atuin system-wide
  environment.etc."atuin/config.toml".text = ''
    # Atuin server sync configuration

    sync_address = "https://atuin.home.lan"
    auto_sync = true
    sync_frequency = "300"

    search_mode = "fuzzy"
    filter_mode = "host"
    style = "compact"
    show_preview = true
    filter_mode_shell_up_key_binding = "directory"

    history_filter = [
      "^pass",
      "^password",
      "^secret",
      "^atuin login",
    ]

    update_snapshots = true
    sync.records = true
  '';

  # Simple bash integration - ONLY load Atuin, don't touch anything else
  environment.etc."profile.d/atuin.sh".text = ''
    # Atuin initialization for interactive shells
    if [[ $- == *i* ]] && command -v atuin &> /dev/null; then
      export ATUIN_CONFIG_DIR="/etc/atuin"
      eval "$(${pkgs.atuin}/bin/atuin init bash)"
    fi
  '';

  # Background sync timer
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
