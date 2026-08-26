{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.btrfs;

  # Only creates a snapshot for a given writing subvolume if btrfs reports
  # actual changed files since the last check (via `btrfs subvolume
  # find-new`), not just a raw generation-number difference.
  #
  # Why not just compare the subvolume's Generation field directly: btrfs
  # bumps a subvolume's root generation on periodic housekeeping
  # transactions (commit interval, async discard/TRIM processing, etc.)
  # even when no file inside the subvolume actually changed. Comparing
  # raw generation numbers alone would create "empty" snapshots during
  # idle periods, which — combined with the number-based cleanup — could
  # evict genuinely useful older snapshots. `find-new` operates at the
  # same file-level granularity as `snapper status`, so it only reports
  # real content/metadata changes to actual files, filtering out btrfs's
  # own internal bookkeeping noise.
  writingTick = pkgs.writeShellApplication {
    name = "snapper-writing-tick";
    runtimeInputs = [pkgs.snapper pkgs.btrfs-progs pkgs.gawk pkgs.coreutils pkgs.gnugrep];
    text = ''
      state_dir="/var/lib/snapper-writing"
      mkdir -p "$state_dir"

      ${lib.concatStrings (lib.mapAttrsToList (name: path: ''
          state_file="$state_dir/${name}.lastgen"
          last_gen=$(cat "$state_file" 2>/dev/null || echo 0)

          changed_files=$(btrfs subvolume find-new "${path}" "$last_gen" | grep -v '^transid marker' || true)
          current_gen=$(btrfs subvolume show "${path}" | awk -F: '/Generation:/ {gsub(/[ \t]/,"",$2); print $2}')

          if [ -n "$changed_files" ]; then
            snapper -c ${name} create --cleanup-algorithm number --description auto${toString cfg.snapshotIntervalMinutes}min
            echo "$current_gen" > "$state_file"
          fi
        '')
        cfg.writingSubvolumes)}
    '';
  };

  # ACL argument string for the ".snapshots" directories, e.g. "u:marcin:rx".
  # Built once here so it can be reused for every writing subvolume below.
  snapshotsAcl = lib.concatMapStringsSep "," (u: "u:${u}:rx") cfg.allowUsers;
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
      description = ''
        Users allowed to browse/restore snapshots via snapper. Enforced
        declaratively via systemd-tmpfiles ACL rules, since the
        .snapshots directories are created manually (not via
        `snapper create-config`), so snapper's own ALLOW_USERS setting
        has no effect on their filesystem permissions.
      '';
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

    # Declaratively lock down each ".snapshots" directory on every boot
    # and config activation: root-only base permissions (0750), plus an
    # explicit ACL grant for the allowed users. This is what actually
    # restricts access — snapper's ALLOW_USERS option does nothing here
    # because we create these subvolumes ourselves rather than through
    # `snapper create-config`.
    systemd.tmpfiles.rules = lib.concatMap (
      path:
        ["z ${path}/.snapshots 0750 root root - -"]
        ++ lib.optional (cfg.allowUsers != []) "a+ ${path}/.snapshots - - - - ${snapshotsAcl}"
    ) (builtins.attrValues cfg.writingSubvolumes);

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
