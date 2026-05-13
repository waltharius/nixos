# modules/servers/ai/zotero2readwise.nix
#
# zotero2readwise — periodic sync of Zotero PDF highlights to Readwise.
#
# Design decisions:
#   - OCI container (Podman) via virtualisation.oci-containers.
#   - autoStart = false; the systemd timer drives execution on schedule.
#   - The image entrypoint is `crond -f` with a baked-in crontab that
#     hardcodes placeholder credentials as POSITIONAL CLI ARGS — env vars
#     are not read by run.py at all. We bypass crond by overriding the
#     container cmd to call a wrapper script written at ExecStartPre.
#   - prepScript writes /run/zotero2readwise-cmd (chmod 0700) containing
#     the exact python invocation with real secrets injected as positional
#     args. This file is bind-mounted into the container and executed
#     directly, so secrets never appear in the Nix store or systemd env.
#   - sops-nix is an activation script, not a systemd service — no
#     Requires/After on sops-nix.service is needed.
#
# Verified call signature (from crontab inside container):
#   python /usr/src/Zotero2Readwise/zotero2readwise/run.py \
#     <readwise_token> <zotero_key> <zotero_user_id> \
#     [--filter-colors COLOR ...]
#
# Scheduling:
#   Syncs every 6 hours by default. Adjust timer via cfg.syncInterval.
#
# Volumes:
#   /run/zotero2readwise-cmd — runtime wrapper script (tmpfs, wiped after run)
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

  # Build a wrapper script at runtime containing secrets as positional args.
  # Written to tmpfs (/run) with mode 0700 — never touches the Nix store.
  # The container bind-mounts /run/zotero2readwise-cmd and executes it.
  prepScript = pkgs.writeShellScript "zotero2readwise-prep" ''
    set -euo pipefail

    SECRETS_DIR=/run/secrets
    CMD_FILE=/run/zotero2readwise-cmd

    RW_TOKEN="$(cat "$SECRETS_DIR/zotero2readwise-readwise-token")"
    ZT_KEY="$(cat   "$SECRETS_DIR/zotero2readwise-zotero-key")"
    ZT_ID="$(cat    "$SECRETS_DIR/zotero2readwise-zotero-id")"

    install -m 0700 /dev/null "$CMD_FILE"
    printf '#!/bin/sh\nexec /usr/local/bin/python /usr/src/Zotero2Readwise/zotero2readwise/run.py "%s" "%s" "%s" --filter-colors %s\n' \
      "$RW_TOKEN" "$ZT_KEY" "$ZT_ID" \
      "${concatStringsSep " " cfg.filterColors}" \
      >> "$CMD_FILE"
  '';

  cleanupScript = pkgs.writeShellScript "zotero2readwise-cleanup" ''
    rm -f /run/zotero2readwise-cmd
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
        Retrieve with: podman inspect zotero2readwise --format '{{.Id}}'
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

    # SOPS secrets — decrypted to /run/secrets/ during nixos-activation.
    # sops-nix is an activation script, not a systemd service, so all
    # secrets are present before any service starts. No ordering needed.
    sops.secrets."zotero2readwise-readwise-token" = {
      sopsFile = ../../../secrets/altair.yaml;
    };
    sops.secrets."zotero2readwise-zotero-key" = {
      sopsFile = ../../../secrets/altair.yaml;
    };
    sops.secrets."zotero2readwise-zotero-id" = {
      sopsFile = ../../../secrets/altair.yaml;
    };

    virtualisation.oci-containers.containers.zotero2readwise = {
      image     = cfg.image;
      autoStart = false;

      # Override crond entrypoint — execute the runtime wrapper script directly.
      # The wrapper is written by prepScript at ExecStartPre with real secrets
      # injected as positional args matching run.py's calling convention.
      entrypoint = "/bin/sh";
      cmd        = [ "/run/zotero2readwise-cmd" ];

      # Bind-mount the runtime cmd file into the container.
      # /run on the host is tmpfs — the file never persists across reboots.
      volumes = [ "/run/zotero2readwise-cmd:/run/zotero2readwise-cmd:ro" ];

      environment = {
        ZOTERO_LIBRARY_TYPE = cfg.zoteroLibraryType;
      };
    };

    # Extend the oci-containers-generated service:
    #   1. ExecStartPre: write the cmd wrapper with real secrets
    #   2. ExecStopPost: wipe the cmd wrapper immediately after each run
    #   3. Restart=no: timer-driven jobs must not auto-restart on failure
    systemd.services."podman-zotero2readwise" = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

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
        Persistent         = true;
        RandomizedDelaySec = "5min";
        Unit               = "podman-zotero2readwise.service";
      };
    };
  };
}
