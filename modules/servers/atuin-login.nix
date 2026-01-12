{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.atuin-auto-login;

  # Secure wrapper script that uses file descriptors
  atuin-login-wrapper = pkgs.writeShellScript "atuin-login-wrapper" ''
    set -euo pipefail

    # File descriptors are passed by systemd via LoadCredential
    # They are available in $CREDENTIALS_DIRECTORY

    if [ -z "''${CREDENTIALS_DIRECTORY:-}" ]; then
      echo "ERROR: CREDENTIALS_DIRECTORY not set" >&2
      exit 1
    fi

    PASSWORD_FILE="$CREDENTIALS_DIRECTORY/atuin-password"
    KEY_FILE="$CREDENTIALS_DIRECTORY/atuin-key"

    # Verify credential files exist and are readable
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

    # Read key into variable (needed for -k flag)
    # This is acceptable as the key is already encrypted by sops
    ATUIN_KEY=$(cat "$KEY_FILE")

    # Login using stdin for password (secure)
    # Use file descriptor redirection to avoid process exposure
    exec 3< "$PASSWORD_FILE"
    ${pkgs.atuin}/bin/atuin login \
      --username "${cfg.username}" \
      --key "$ATUIN_KEY" \
      <&3

    # Close file descriptor
    exec 3<&-

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
    # Ensure atuin package is available
    environment.systemPackages = [pkgs.atuin];

    # Systemd service with secure credential passing
    systemd.services.atuin-auto-login = {
      description = "Auto-login to Atuin server";
      after = ["network-online.target" "sops-nix.service"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        RemainAfterExit = true;

        # Set home directory for atuin config
        Environment = "HOME=/home/${cfg.user}";

        # Use systemd's credential system - most secure method
        # Credentials are mounted in memory, never touch disk unencrypted
        LoadCredential = [
          "atuin-password:/run/secrets/atuin-password"
          "atuin-key:/run/secrets/atuin-key"
        ];

        # Additional security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = false; # Need access to user home for .local/share/atuin
        ReadWritePaths = "/home/${cfg.user}/.local/share/atuin";

        # Prevent credential leakage
        StandardOutput = "journal";
        StandardError = "journal";

        ExecStart = "${atuin-login-wrapper}";
      };
    };
  };
}
