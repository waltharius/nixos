# Atuin with automatic sync to self-hosted server
# Credentials are managed via sops-nix secrets
# Works on both laptops (systemd) and servers (no daemon)
{
  config,
  lib,
  pkgs,
  osConfig ? {},
  ...
}:
with lib; let
  # Check if we have access to system config (for secrets path)
  hasSecrets = osConfig ? sops.secrets.atuin-password;
  
  # Determine if we're on a graphical system (laptop) or server
  isGraphical = osConfig ? services.xserver.enable && osConfig.services.xserver.enable or false;
in {
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;

    settings = {
      # Self-hosted server
      sync_address = "https://atuin.home.lan";
      
      # Auto-sync settings
      auto_sync = true;
      sync_frequency = "5m";  # Sync every 5 minutes

      sync = {
        records = true;
      };

      # Daemon only on graphical systems (laptops)
      daemon = {
        enabled = isGraphical;
        sync_frequency = if isGraphical then 300 else 0;  # 5 minutes in seconds
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
        "^atuin register"
      ];
    };
  };

  # Automatic login script using sops secrets
  # Runs on system activation to ensure atuin is always logged in
  home.activation.atuinLogin = mkIf hasSecrets (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Check if atuin is already logged in
      if ! ${pkgs.atuin}/bin/atuin status &>/dev/null; then
        echo "Atuin: Logging in to server..."
        
        # Read credentials from sops secrets
        ATUIN_PASSWORD=$(cat ${osConfig.sops.secrets.atuin-password.path})
        ATUIN_KEY=$(cat ${osConfig.sops.secrets.atuin-key.path})
        
        # Login with credentials
        echo "$ATUIN_PASSWORD" | ${pkgs.atuin}/bin/atuin login \
          -u admin \
          -k "$ATUIN_KEY" || true
        
        echo "Atuin: Login complete"
      else
        echo "Atuin: Already logged in"
      fi
    ''
  );

  # Systemd service for background sync (laptops only)
  systemd.user.services.atuin-daemon = mkIf (hasSecrets && isGraphical) {
    Unit = {
      Description = "Atuin Shell History Daemon";
      After = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${pkgs.atuin}/bin/atuin daemon";
      Restart = "on-failure";
      RestartSec = "30s";
    };

    Install = {
      WantedBy = ["default.target"];
    };
  };

  # Cron-based sync for servers (no systemd user session)
  # Syncs every 5 minutes via system cron
  # Note: This requires system-level configuration in NixOS
  # For servers, add to configuration.nix:
  #   services.cron.enable = true;
  #   services.cron.systemCronJobs = [
  #     "*/5 * * * * nixadm ${pkgs.atuin}/bin/atuin sync"
  #   ];
}
