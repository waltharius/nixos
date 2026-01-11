# Atuin with automatic sync to self-hosted server
# Credentials are managed via sops-nix secrets
# Works on both laptops (systemd) and servers (no daemon)
{
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
      sync_frequency = "5m";

      sync = {
        records = true;
      };

      # Daemon only on graphical systems (laptops)
      daemon = {
        enabled = isGraphical;
        sync_frequency =
          if isGraphical
          then 300
          else 0; # 5 minutes in seconds
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

  # Systemd oneshot service to login to Atuin after secrets are ready
  systemd.user.services.atuin-login = mkIf hasSecrets {
    Unit = {
      Description = "Atuin auto-login to server";
      After = ["sops-nix.service"]; # Wait for sops to decrypt
      ConditionPathExists = osConfig.sops.secrets.atuin-password.path;
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "atuin-login" ''
        PATH="${pkgs.coreutils}/bin:${pkgs.atuin}/bin"

        # Check if already logged in
        if atuin status &>/dev/null; then
          echo "Atuin: Already logged in"
          exit 0
        fi

        echo "Atuin: Logging in to server..."

        # Read credentials from sops secrets
        ATUIN_PASSWORD=$(cat ${osConfig.sops.secrets.atuin-password.path})
        ATUIN_KEY=$(cat ${osConfig.sops.secrets.atuin-key.path})

        # Login with credentials using expect-style
        ${pkgs.expect}/bin/expect -c "
          set timeout 10
          spawn atuin login -u admin -k \"$ATUIN_KEY\"
          expect \"Please enter password:\"
          send \"$ATUIN_PASSWORD\r\"
          expect eof
        " || {
          echo "Atuin: Login failed, but continuing..."
        }

        echo "Atuin: Login complete"
      '';
    };

    Install = {
      WantedBy = ["default.target"];
    };
  };

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
