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
#     the exact python invocation with real secrets as positional args.
#     This file is bind-mounted into the container and executed directly.
#   - sops-nix is an activation script, not a systemd service — no
#     Requires/After on sops-nix.service is needed.
#
# Verified call signature (from run.py source):
#   python run.py <readwise_token> <zotero_key> <zotero_library_id> \
#     [--filter_color COLOR] ...   # action=append, repeatable
#     [--use_since]                # only sync highlights since last run
#
#   --filter_color default=[] means no flags → sync ALL colors.
#   Hex values (#xxxxxx) MUST be double-quoted in the generated sh script
#   because bare # is a comment character in sh.
#
# Scheduling:
#   Syncs every 6 hours by default. Adjust timer via cfg.syncInterval.
#   useSince=true (default) means only new highlights are pushed after
#   the first full sync, keeping API calls minimal.
#
# Volumes:
#   /run/zotero2readwise-cmd — runtime wrapper (tmpfs, wiped after run)
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

  # Build repeated --filter_color flags, one per colour.
  # double-quoted so the generated /bin/sh script does not treat # as comment.
  # Empty list → no flags → run.py syncs all colors (its default behaviour).
  filterColorFlags = concatMapStringsSep " " (c: "--filter_color \"${c}\"") cfg.filterColors;

  useSinceFlag = if cfg.useSince then "--use_since" else "";

  # Build a wrapper script at runtime containing secrets as positional args.
  # Written to tmpfs (/run) with mode 0700 — never touches the Nix store.
  prepScript = pkgs.writeShellScript "zotero2readwise-prep" ''
    set -euo pipefail

    SECRETS_DIR=/run/secrets
    CMD_FILE=/run/zotero2readwise-cmd

    RW_TOKEN="$(cat "$SECRETS_DIR/zotero2readwise-readwise-token")"
    ZT_KEY="$(cat   "$SECRETS_DIR/zotero2readwise-zotero-key")"
    ZT_ID="$(cat    "$SECRETS_DIR/zotero2readwise-zotero-id")"

    install -m 0700 /dev/null "$CMD_FILE"
    printf '#!/bin/sh\nexec /usr/local/bin/python /usr/src/Zotero2Readwise/zotero2readwise/run.py "%s" "%s" "%s" ${filterColorFlags} ${useSinceFlag}\n' \
      "$RW_TOKEN" "$ZT_KEY" "$ZT_ID" \
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
      # Default excludes grey (#aaaaaa) — used for navigation/chapter headings.
      # Set to [] to sync all colors.
      default = [ "#ffd400" "#ff6666" "#5fb236" "#2ea8e5" "#a28ae5" "#e56eee" "#f19837" ];
      example = [ "#ffd400" "#ff6666" ];
      description = ''
        Highlight colours to include. Each becomes a --filter_color flag.
        Set to [] to sync all colours including grey.
        Zotero palette: yellow=#ffd400 red=#ff6666 green=#5fb236
          blue=#2ea8e5 purple=#a28ae5 magenta=#e56eee orange=#f19837
          grey=#aaaaaa (excluded by default — used for navigation highlights)
      '';
    };

    useSince = mkOption {
      type    = types.bool;
      default = true;
      description = ''
        Pass --use_since to run.py so only highlights added since the last
        successful sync are pushed. Keeps API calls minimal on repeat runs.
        Set to false to force a full re-sync (e.g. after credential change).
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

      # Bypass crond: execute the runtime wrapper script directly.
      entrypoint = "/bin/sh";
      cmd        = [ "/run/zotero2readwise-cmd" ];

      # Bind-mount the runtime cmd wrapper into the container (read-only).
      volumes = [ "/run/zotero2readwise-cmd:/run/zotero2readwise-cmd:ro" ];

      environment = {
        ZOTERO_LIBRARY_TYPE = cfg.zoteroLibraryType;
      };
    };

    systemd.services."podman-zotero2readwise" = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        ExecStartPre = [ "+${prepScript}" ];
        ExecStopPost = [ "+${cleanupScript}" ];
        Restart      = mkForce "no";
      };
    };

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
