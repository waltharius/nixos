# modules/servers/ai/zotero2readwise.nix
#
# zotero2readwise — periodic sync of Zotero PDF highlights to Readwise.
#
# Design decisions:
#   - OCI container (Podman) via virtualisation.oci-containers.
#   - autoStart = false; the systemd timer drives execution on schedule.
#   - The generated podman-zotero2readwise.service uses Type=notify (set by
#     oci-containers internally). We must NOT override Type — instead we
#     inject ExecStartPre/ExecStopPost via serviceConfig and use mkForce
#     only for Restart to suppress the default on-failure policy.
#   - Secrets (API keys, user ID) are SOPS-decrypted during nixos-activation
#     (before systemd services start) to /run/secrets/* by sops-nix.
#     prepScript assembles them into an EnvironmentFile at ExecStartPre.
#     This avoids secrets appearing in `systemctl show` env dumps.
#   - sops-nix does NOT run as a systemd service — it is an activation script.
#     No Requires/After on sops-nix.service is needed or possible.
#
# Image env vars (verified via podman inspect):
#   ZOTERO_USER_ID     — Zotero numeric user/library ID
#   ZOTERO_API_KEY     — Zotero API key
#   READWISE_API_KEY   — Readwise API token
#
# Scheduling:
#   Syncs every 6 hours by default. Adjust timer via cfg.syncInterval.
#
# Volumes:
#   none — stateless, all state is in Zotero cloud and Readwise cloud.
#
# Ports:
#   none — outbound HTTPS only to api.zotero.org and readwise.io.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.server-role.zotero2readwise;

  # Assemble the EnvironmentFile from SOPS-decrypted secrets at runtime.
  # Variable names verified against image defaults via:
  #   podman inspect zotero2readwise --format '{{.Config.Env}}'
  # Result: ZOTERO_USER_ID, ZOTERO_API_KEY, READWISE_API_KEY
  prepScript = pkgs.writeShellScript "zotero2readwise-prep" ''
    set -euo pipefail

    SECRETS_DIR=/run/secrets
    ENV_FILE=/run/zotero2readwise.env

    install -m 0600 /dev/null "$ENV_FILE"

    printf 'READWISE_API_KEY=%s\n' "$(cat "$SECRETS_DIR/zotero2readwise-readwise-token")" >> "$ENV_FILE"
    printf 'ZOTERO_API_KEY=%s\n'   "$(cat "$SECRETS_DIR/zotero2readwise-zotero-key")"     >> "$ENV_FILE"
    printf 'ZOTERO_USER_ID=%s\n'   "$(cat "$SECRETS_DIR/zotero2readwise-zotero-id")"      >> "$ENV_FILE"
  '';

  cleanupScript = pkgs.writeShellScript "zotero2readwise-cleanup" ''
    rm -f /run/zotero2readwise.env
  '';
in {
  options.services.server-role.zotero2readwise = {
    enable = mkEnableOption "Zotero → Readwise highlight sync";

    image = mkOption {
      type    = types.str;
      default = "docker.io/justinlee901227/zotero2readwise:latest";
      description = ''
        OCI image to use. Consider pinning to a specific digest once tested:
          docker.io/justinlee901227/zotero2readwise@sha256:<digest>
        Retrieve with: podman pull --quiet ... && podman inspect ... | jq '.[0].Digest'
      '';
    };

    zoteroLibraryType = mkOption {
      type    = types.enum [ "user" "group" ];
      default = "user";
      description = "Zotero library type: 'user' or 'group'.";
    };

    filterColors = mkOption {
      type    = types.listOf types.str;
      default = [ "#ffd400" "#ff6666" "#5fb236" "#2ea8e5" "#a28ae5" "#e56eee" ];
      example = [ "#ffd400" "#ff6666" ];
      description = ''
        Highlight colours to sync. Grey (#aaaaaa) is excluded by default —
        it is commonly used for navigation/chapter title highlights that
        should not appear in Readwise.
        Full Zotero palette: yellow=#ffd400 red=#ff6666 green=#5fb236
          blue=#2ea8e5 purple=#a28ae5 pink=#e56eee grey=#aaaaaa
      '';
    };

    syncInterval = mkOption {
      type    = types.str;
      default = "*-*-* 00,06,12,18:00:00";
      description = ''
        OnCalendar expression for the systemd timer.
        Default: every 6 hours on the hour.
      '';
    };
  };

  config = mkIf cfg.enable {

    # SOPS secrets — decrypted to /run/secrets/ during nixos-activation by
    # sops-nix (activation script, not a systemd service). All secrets are
    # present before systemd starts any services, so no ordering dependency
    # on sops-nix is required.
    sops.secrets."zotero2readwise-readwise-token" = {
      sopsFile = ../../../secrets/altair.yaml;
    };
    sops.secrets."zotero2readwise-zotero-key" = {
      sopsFile = ../../../secrets/altair.yaml;
    };
    sops.secrets."zotero2readwise-zotero-id" = {
      sopsFile = ../../../secrets/altair.yaml;
    };

    # autoStart = false — the systemd timer drives execution, not boot.
    # oci-containers still generates the podman-zotero2readwise.service unit
    # and manages image pulls; we just don't want it starting at boot.
    virtualisation.oci-containers.containers.zotero2readwise = {
      image     = cfg.image;
      autoStart = false;

      # EnvironmentFile written by ExecStartPre — secrets never in unit env dump
      environmentFiles = [ "/run/zotero2readwise.env" ];

      environment = {
        ZOTERO_LIBRARY_TYPE = cfg.zoteroLibraryType;
        # Space-separated colour list consumed by the entrypoint
        FILTER_COLORS       = concatStringsSep " " cfg.filterColors;
      };
    };

    # Extend the oci-containers-generated service with:
    #   1. Ordering: wait for network only (sops secrets already present)
    #   2. ExecStartPre: assemble the EnvironmentFile from /run/secrets/*
    #   3. ExecStopPost: wipe the EnvironmentFile immediately after each run
    #   4. Restart=no (mkForce): oci-containers defaults to on-failure;
    #      for a timer-driven job we never want automatic restarts.
    #
    # DO NOT set serviceConfig.Type here — oci-containers owns it (notify).
    systemd.services."podman-zotero2readwise" = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # '+' prefix on ExecStartPre runs the script as root so it can read
      # /run/secrets/* which are root-owned by sops-nix.
      serviceConfig = {
        ExecStartPre = [ "+${prepScript}" ];
        ExecStopPost = [ "+${cleanupScript}" ];
        Restart      = mkForce "no";
      };
    };

    # Systemd timer — triggers the service on schedule
    systemd.timers."podman-zotero2readwise" = {
      wantedBy  = [ "timers.target" ];
      timerConfig = {
        OnCalendar         = cfg.syncInterval;
        # Fire immediately on first enable if the last trigger was missed
        Persistent         = true;
        # Spread ±5 min to avoid exact-on-the-hour thundering herd
        RandomizedDelaySec = "5min";
        Unit               = "podman-zotero2readwise.service";
      };
    };
  };
}
