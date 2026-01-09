{
  pkgs,
  config,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [atuin];

  environment.etc."atuin/config.toml".text = ''
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
  programs.bash = {
    enableCompletion = true;

    interactiveShellInit = ''
      # Atuin initialization
      if command -v atuin &> /dev/null; then
        export ATUIN_CONFIG_DIR="/etc/atuin"

        # CRITICAL: Generate session ID if not exists
        if [ -z "$ATUIN_SESSION" ]; then
          export ATUIN_SESSION="$(${pkgs.atuin}/bin/atuin uuid)"
        fi

        # Initialize atuin (this sets up PROMPT_COMMAND correctly)
        eval "$(${pkgs.atuin}/bin/atuin init bash --disable-up-arrow)"

        # Bind Ctrl+R
        bind -x '"\C-r": __atuin_history'
      fi
    '';

    # Bash completion for atuin
    enableLsColors = true;
  };

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
      ExecStart = "${pkgs.bash}/bin/bash -c 'export ATUIN_CONFIG_DIR=/etc/atuin && ${pkgs.atuin}/bin/atuin sync'";
      User = "root";
    };
    environment = {
      ATUIN_CONFIG_DIR = "/etc/atuin";
      HOME = "/root";
    };
  };
}
