# Atuin shell history with server sync for containers/servers
{pkgs, ...}: {
  # Install atuin system-wide
  environment.systemPackages = with pkgs; [atuin];

  # Configure atuin system-wide
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

  # System-wide bashrc with Atuin integration
  environment.etc."bashrc".text = ''
    # Only for interactive shells
    [[ $- == *i* ]] || return

    # Check if atuin is available
    if ! command -v atuin &> /dev/null; then
      return
    fi

    # Set Atuin config directory
    export ATUIN_CONFIG_DIR="/etc/atuin"

    # Initialize Atuin
    eval "$(${pkgs.atuin}/bin/atuin init bash --disable-up-arrow)"

    # CRITICAL: Ensure PROMPT_COMMAND is set
    # Sometimes the eval doesn't set it properly, so we force it
    if [[ -z "$PROMPT_COMMAND" ]] || [[ "$PROMPT_COMMAND" != *"__atuin_precmd"* ]]; then
      PROMPT_COMMAND="__atuin_precmd"
    fi

    # Bind Ctrl+R to Atuin search
    bind -x '"\C-r": __atuin_history'
  '';

  environment.etc."profile.d/atuin.sh".text = ''
    # This ensures atuin is loaded for login shells (like SSH sessions)
    if [[ $- == *i* ]]; then
      if [ -f /etc/bash.bashrc ]; then
        source /etc/bash.bashrc
      fi
    fi
  '';

  # Create root's .bashrc to source system bashrc
  system.activationScripts.rootBashrc = ''
    mkdir -p /root
    cat > /root/.bashrc << 'EOF'
    # Source global bashrc
    if [ -f /etc/bash.bashrc ]; then
      source /etc/bash.bashrc
    fi

    # Verify Atuin is active (debugging)
    if command -v atuin &> /dev/null; then
      # Verify PROMPT_COMMAND is set
      if [[ -z "$PROMPT_COMMAND" ]]; then
        echo "WARNING: PROMPT_COMMAND not set, atuin history will not be saved!"
        export PROMPT_COMMAND="__atuin_precmd"
      fi
    fi
    EOF

    # Ensure proper permissions
    chmod 644 /root/.bashrc
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
