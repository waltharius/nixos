{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.atuin-auto-login;

  # Secure wrapper that feeds password via here-string (works in systemd)
  atuin-login-wrapper = pkgs.writeShellScript "atuin-login-wrapper" ''
    set -euo pipefail

    if [ -z "''${CREDENTIALS_DIRECTORY:-}" ]; then
      echo "ERROR: CREDENTIALS_DIRECTORY not set" >&2
      exit 1
    fi

    PASSWORD_FILE="$CREDENTIALS_DIRECTORY/atuin-password"
    KEY_FILE="$CREDENTIALS_DIRECTORY/atuin-key"

    if [ ! -r "$PASSWORD_FILE" ] || [ ! -r "$KEY_FILE" ]; then
      echo "ERROR: Credential files not accessible" >&2
      exit 1
    fi

    # Check if already logged in
    if ${pkgs.atuin}/bin/atuin status &>/dev/null; then
      echo "Already logged in to Atuin"
      exit 0
    fi

    echo "Logging in to Atuin server..."

    # Read credentials into variables
    ATUIN_PASSWORD=$(cat "$PASSWORD_FILE")
    ATUIN_KEY=$(cat "$KEY_FILE")

    # Use here-string to feed password to stdin
    # This works even when stdin is closed by systemd
    ${pkgs.atuin}/bin/atuin login \
      --username "${cfg.username}" \
      --key "$ATUIN_KEY" \
      <<< "$ATUIN_PASSWORD"

    if [ $? -eq 0 ]; then
      echo "Successfully logged in to Atuin"
      exit 0
    else
      echo "Failed to login to Atuin" >&2
      exit 1
    fi
  '';
in {
  options.services.atuin-auto-login = {
    enable = mkEnableOption "Automatic Atuin login for servers";

    user = mkOption {
      type = types.str;
      default = "nixadm";
      description = "User to run atuin login as";
    };

    username = mkOption {
      type = types.str;
      default = "nixadm";
      description = "Atuin server username";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.atuin];

    systemd.services.atuin-auto-login = {
      description = "Auto-login to Atuin server";
      after = ["network-online.target" "sops-nix.service"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        RemainAfterExit = true;

        Environment = "HOME=/home/${cfg.user}";

        # Use systemd's credential system
        LoadCredential = [
          "atuin-password:/run/secrets/atuin-password"
          "atuin-key:/run/secrets/atuin-key"
        ];

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = false;
        ReadWritePaths = "/home/${cfg.user}/.local/share/atuin";

        StandardOutput = "journal";
        StandardError = "journal";

        ExecStart = "${atuin-login-wrapper}";
      };
    };
  };
}
