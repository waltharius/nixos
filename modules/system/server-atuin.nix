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

  # Create root's .bashrc to source system bashrc
  system.activationScripts.rootBashrc = ''
    cat > /root/.bashrc << 'EOF'
    # Source system bashrc
    if [ -f /etc/bashrc ]; then
      source /etc/bashrc
    fi

    # Verify Atuin hooks are active
    if command -v atuin &> /dev/null; then
      # Ensure PROMPT_COMMAND includes Atuin
      if [[ -z "$PROMPT_COMMAND" ]] || [[ "$PROMPT_COMMAND" != *"__atuin_precmd"* ]]; then
        export PROMPT_COMMAND="__atuin_precmd"
      fi
    fi
    EOF
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
