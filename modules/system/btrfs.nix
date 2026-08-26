{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.btrfs;

  # Only creates a snapshot for a given writing subvolume if its btrfs
  # generation number changed since the last check. This prevents idle
  # periods (e.g. a multi-hour break) from flooding the number-limited
  # snapshot history with identical, content-free snapshots that would
  # otherwise evict older, meaningful ones.
  writingTick = pkgs.writeShellApplication {
    name = "snapper-writing-tick";
    runtimeInputs = [pkgs.snapper pkgs.btrfs-progs pkgs.gawk pkgs.coreutils];
    text = ''
      state_dir="/var/lib/snapper-writing"
      mkdir -p "$state_dir"

      ${lib.concatStrings (lib.mapAttrsToList (name: path: ''
          gen=$(btrfs subvolume show "${path}" | awk -F: '/Generation:/ {gsub(/[ \t]/,"",$2); print $2}')
          state_file="$state_dir/${name}.lastgen"
          last_gen=$(cat "$state_file" 2>/dev/null || echo 0)
          if [ "$gen" != "$last_gen" ]; then
            snapper -c ${name} create --cleanup-algorithm number --description auto${toString cfg.snapshotIntervalMinutes}min
            echo "$gen" > "$state_file"
          fi
        '')
        cfg.writingSubvolumes)}
    '';
  };
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
      description = "How often (in minutes) to check the writing subvolumes for changes and snapshot them if needed.";
    };

    snapshotNumberLimit = lib.mkOption {
      type = lib.types.int;
      default = 80; # ~4 hours of history at the default 3-minute interval, assuming continuous changes
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
        TIMELINE_CREATE = false; # handled by our own change-aware timer below
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
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${writingTick}/bin/snapper-writing-tick";
        StateDirectory = "snapper-writing"; # systemd creates /var/lib/snapper-writing for us
      };
    };
  };
}
