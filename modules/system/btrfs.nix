# modules/system/btrfs.nix
#
# Shared role for every host whose root filesystem is btrfs.
# Import this on any btrfs host — it always enables scrub, and
# conditionally sets up frequent snapshotting for whatever writing
# subvolumes the host declares via `custom.btrfs.writingSubvolumes`.
#
# Design note: snapshot behavior is driven entirely by data (the
# writingSubvolumes option), not by whether some other file happens
# to be imported. If a host stops declaring subvolumes here, the
# snapper configs and timer disappear automatically — no errors about
# missing subvolumes, no manual cleanup required.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.btrfs;
in {
  options.custom.btrfs = {
    writingSubvolumes = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = ''
        Name -> absolute path mapping of btrfs subvolumes that hold
        actively-edited content (documents, notes, sync folders) and
        should get frequent, short-retention snapshots as a safety net
        against application bugs that corrupt files mid-edit.
      '';
      example = {
        documents = "/home/marcin/Documents";
        notes = "/home/marcin/notes";
      };
    };

    allowUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Users allowed to browse/restore snapshots via snapper.";
    };

    snapshotIntervalMinutes = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "How often (in minutes) to snapshot the writing subvolumes.";
    };

    snapshotNumberLimit = lib.mkOption {
      type = lib.types.int;
      default = 80; # ~4 hours of history at the default 3-minute interval
      description = "Maximum number of frequent snapshots kept per writing subvolume.";
    };
  };

  config = {
    # Scrub applies to the whole physical volume, so this is always
    # correct regardless of how many subvolumes exist on top of it.
    services.btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      fileSystems = ["/"];
    };

    services.snapper.configs =
      lib.mapAttrs (name: path: {
        SUBVOLUME = path;
        ALLOW_USERS = cfg.allowUsers;
        TIMELINE_CREATE = false; # handled by our own faster timer below
        NUMBER_CLEANUP = true;
        NUMBER_LIMIT = cfg.snapshotNumberLimit;
        NUMBER_MIN_AGE = 0;
      })
      cfg.writingSubvolumes;

    services.snapper.cleanupInterval = "1d";

    systemd.timers.snapper-writing-frequent = lib.mkIf (cfg.writingSubvolumes != {}) {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*:0/${toString cfg.snapshotIntervalMinutes}";
        Persistent = true;
      };
    };

    systemd.services.snapper-writing-frequent = lib.mkIf (cfg.writingSubvolumes != {}) {
      serviceConfig.Type = "oneshot";
      serviceConfig.ExecStart = lib.concatMapStringsSep "\n" (
        name: "${pkgs.snapper}/bin/snapper -c ${name} create --cleanup-algorithm number --description auto${toString cfg.snapshotIntervalMinutes}min"
      ) (builtins.attrNames cfg.writingSubvolumes);
    };
  };
}
