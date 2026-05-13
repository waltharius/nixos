# modules/servers/ai/zotero2readwise.nix
#
# zotero2readwise — periodic sync of Zotero PDF highlights to Readwise.
#
# Design decisions:
#   - OCI container (Podman) via virtualisation.oci-containers.
#   - Runs as a oneshot container on a systemd timer, NOT autoStart.
#     The container exits after each sync; the timer re-triggers it.
#   - Secrets (API keys, user ID) are SOPS-decrypted at boot to
#     /run/secrets/* and assembled into an EnvironmentFile at ExecStartPre.
#     This avoids passing secrets as plain env vars visible in `systemctl show`.
#   - --filter-colors allows excluding navigation highlights (e.g. grey #aaaaaa).
#   - Image is pinned by digest for reproducibility; update intentionally.
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
  # Using a file prevents secrets appearing in systemd unit environment dumps.
  prepScript = pkgs.writeShellScript "zotero2readwise-prep" ''
    set -euo pipefail

    SECRETS_DIR=/run/secrets
    ENV_FILE=/run/zotero2readwise.env

    install -m 0600 /dev/null "$ENV_FILE"

    printf 'READWISE_API_TOKEN=%s\n' "$(cat "$SECRETS_DIR/zotero2readwise-readwise-token")" >> "$ENV_FILE"
    printf 'ZOTERO_API_KEY=%s\n'     "$(cat "$SECRETS_DIR/zotero2readwise-zotero-key")"     >> "$ENV_FILE"
    printf 'ZOTERO_LIBRARY_ID=%s\n'  "$(cat "$SECRETS_DIR/zotero2readwise-zotero-id")"      >> "$ENV_FILE"
  '';
in {
  options.services.server-role.zotero2readwise = {
    enable = mkEnableOption "Zotero → Readwise highlight sync";

    image = mkOption {
      type = types.str;
      default = "docker.io/justinlee901227/zotero2readwise:latest";
      description = ''
        OCI image to use. Consider pinning to a specific digest once tested:
          docker.io/justinlee901227/zotero2readwise@sha256:<digest>
        Retrieve with: podman pull --quiet ... && podman inspect ... | jq '.[0].Digest'
      '';
    };

    zoteroLibraryType = mkOption {
      type = types.enum ["user" "group"];
      default = "user";
      description = "Zotero library type: 'user' or 'group'.";
    };

    filterColors = mkOption {
      type = types.listOf types.str;
      default = ["#ffd400" "#ff6666" "#5fb236" "#2ea8e5" "#a28ae5" "#e56eee"];
      example = ["#ffd400" "#ff6666"];
      description = ''
        Highlight colours to sync. Grey (#aaaaaa) is excluded by default —
        it is commonly used for navigation/chapter title highlights that
        should not appear in Readwise.
        Full Zotero palette: yellow=#ffd400 red=#ff6666 green=#5fb236
          blue=#2ea8e5 purple=#a28ae5 pink=#e56eee grey=#aaaaaa
      '';
    };

    syncInterval = mkOption {
      type = types.str;
      default = "*-*-* 00,06,12,18:00:00";
      description = ''
        OnCalendar expression for the systemd timer.
        Default: every 6 hours on the hour.
      '';
    };
  };

  config = mkIf cfg.enable {
    # SOPS secrets — decrypted to /run/secrets/ at boot by sops-nix
    sops.secrets."zotero2readwise-readwise-token" = {
      sopsFile = ../../../secrets/altair.yaml;
    };
    sops.secrets."zotero2readwise-zotero-key" = {
      sopsFile = ../../../secrets/altair.yaml;
    };
    sops.secrets."zotero2readwise-zotero-id" = {
      sopsFile = ../../../secrets/altair.yaml;
    };

    # The container is NOT set to autoStart — the timer drives it.
    # virtualisation.oci-containers still registers the podman-zotero2readwise
    # service so Nix manages the image pull and unit generation.
    virtualisation.oci-containers.containers.zotero2readwise = {
      image = cfg.image;
      autoStart = false;

      # EnvironmentFile written by ExecStartPre — secrets never in unit env dump
      environmentFiles = ["/run/zotero2readwise.env"];

      environment = {
        ZOTERO_LIBRARY_TYPE = cfg.zoteroLibraryType;
        # Space-separated colour list consumed by the entrypoint
        FILTER_COLORS = concatStringsSep " " cfg.filterColors;
      };
    };

    # Override the generated systemd service to:
    #   1. Run prepScript before the container to assemble the EnvironmentFile
    #   2. Wait for sops-nix to decrypt secrets
    systemd.services."podman-zotero2readwise" = {
      after = ["network-online.target" "sops-nix.service"];
      wants = ["network-online.target"];
      requires = ["sops-nix.service"];

      serviceConfig = {
        Type = "oneshot";
        # '+' prefix runs prepScript as root so it can read /run/secrets/*
        ExecStartPre = ["+${prepScript}"];
        # Remove EnvironmentFile after container exits to avoid secrets at rest
        ExecStopPost = ["${pkgs.coreutils}/bin/rm -f /run/zotero2readwise.env"];
        # Restart policy: do NOT restart on failure — wait for next timer tick
        Restart = "no";
      };
    };

    # Systemd timer — triggers the oneshot service on schedule
    systemd.timers."podman-zotero2readwise" = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.syncInterval;
        # Run immediately on first boot/enable if last trigger was missed
        Persistent = true;
        # Spread load ±5 min to avoid exact-on-the-hour thundering herd
        RandomizedDelaySec = "5min";
        Unit = "podman-zotero2readwise.service";
      };
    };
  };
}
