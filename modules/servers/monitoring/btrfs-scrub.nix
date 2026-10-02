# modules/servers/monitoring/btrfs-scrub.nix
#
# Monthly btrfs scrub on bare-metal servers, and its result exported to
# Prometheus through node_exporter's textfile collector. Imported by
# lib/monitoring.nix on machines of class server.
#
# Scrub reads every block and checks it against its checksum, so silent
# corruption on a disk is found while the data can still be repaired or
# restored. A scrub works on a whole filesystem, so it runs once per btrfs
# device, not once per subvolume; nixpkgs picks one mount point per device
# by default (on altair: / for the system disk, /mnt/data for the data
# disk). A host can override `services.btrfs.autoScrub.fileSystems`.
#
# btrfs-scrub-metrics (hourly, cheap: it only reads the status btrfs keeps
# of the last scrub) writes btrfs-scrub.prom:
#   btrfs_scrub_stats_available{mountpoint}  1 once a scrub has run
#   btrfs_scrub_started_timestamp_seconds{mountpoint}
#   btrfs_scrub_finished{mountpoint}         1 when the last scrub finished
#   btrfs_scrub_errors{mountpoint,type}      error counters of the last scrub
#                                            (read_errors, csum_errors, ...)
# Alerts: BtrfsScrubErrors, BtrfsScrubUncorrectable, BtrfsScrubStale.
{
  config,
  lib,
  pkgs,
  ...
}: let
  textfileDir = config.fleet.monitoring.textfileDir;

  btrfsMounts = lib.filterAttrs (_: fs: fs.fsType == "btrfs") config.fileSystems;

  metricsScript = pkgs.writeShellApplication {
    name = "btrfs-scrub-metrics";
    runtimeInputs = [pkgs.btrfs-progs pkgs.coreutils pkgs.gawk pkgs.gnugrep pkgs.gnused];
    text = ''
      # Export the status of the last btrfs scrub of every mount point given
      # as an argument to node_exporter's textfile collector.
      dir=${lib.escapeShellArg textfileDir}
      out="$dir/btrfs-scrub.prom"
      tmp=$(mktemp "$dir/.btrfs-scrub.prom.XXXXXX")
      trap 'rm -f "$tmp"' EXIT

      available="" started="" finished="" errors=""
      for mnt in "$@"; do
        status=$(btrfs scrub status -R "$mnt" 2>/dev/null || true)
        if [ -z "$status" ] || grep -q 'no stats available' <<<"$status"; then
          available+="btrfs_scrub_stats_available{mountpoint=\"$mnt\"} 0"$'\n'
          continue
        fi
        available+="btrfs_scrub_stats_available{mountpoint=\"$mnt\"} 1"$'\n'

        start_text=$(sed -n 's/^Scrub started:[[:space:]]*//p' <<<"$status")
        start=$(date -d "$start_text" +%s 2>/dev/null || echo 0)
        started+="btrfs_scrub_started_timestamp_seconds{mountpoint=\"$mnt\"} $start"$'\n'

        if grep -Eq '^Status:[[:space:]]+finished' <<<"$status"; then
          finished+="btrfs_scrub_finished{mountpoint=\"$mnt\"} 1"$'\n'
        else
          finished+="btrfs_scrub_finished{mountpoint=\"$mnt\"} 0"$'\n'
        fi

        # Raw counters look like "	csum_errors: 0".
        errors+=$(awk -v m="$mnt" '$1 ~ /_errors:$/ { sub(":", "", $1); printf "btrfs_scrub_errors{mountpoint=\"%s\",type=\"%s\"} %s\n", m, $1, $2 }' <<<"$status")$'\n'
      done

      {
        echo "# HELP btrfs_scrub_stats_available 1 if btrfs keeps statistics of a previous scrub."
        echo "# TYPE btrfs_scrub_stats_available gauge"
        printf '%s' "$available"
        echo "# HELP btrfs_scrub_started_timestamp_seconds Start time of the last scrub."
        echo "# TYPE btrfs_scrub_started_timestamp_seconds gauge"
        printf '%s' "$started"
        echo "# HELP btrfs_scrub_finished 1 if the last scrub finished, 0 if it is running, was aborted or interrupted."
        echo "# TYPE btrfs_scrub_finished gauge"
        printf '%s' "$finished"
        echo "# HELP btrfs_scrub_errors Error counters of the last scrub."
        echo "# TYPE btrfs_scrub_errors gauge"
        printf '%s' "$errors" | sed '/^$/d'
      } >"$tmp"

      chmod 0644 "$tmp"
      mv "$tmp" "$out"
    '';
  };
in {
  # nixpkgs already defaults `fileSystems` to one mount point per btrfs
  # device (lib.mkDefault in nixos/modules/tasks/filesystems/btrfs.nix).
  # Setting it here at the same priority would concatenate the two lists
  # and scrub every filesystem twice (stage 5a did exactly that).
  services.btrfs.autoScrub = {
    enable = lib.mkDefault (btrfsMounts != {});
    interval = lib.mkDefault "monthly";
  };

  systemd.services.btrfs-scrub-metrics = lib.mkIf config.services.btrfs.autoScrub.enable {
    description = "Export the last btrfs scrub results to node_exporter";
    serviceConfig = {
      Type = "oneshot";
      # unique: a duplicate mount point would write duplicate series, which
      # node_exporter rejects.
      ExecStart = "${lib.getExe metricsScript} ${lib.escapeShellArgs (lib.unique config.services.btrfs.autoScrub.fileSystems)}";
    };
  };

  systemd.timers.btrfs-scrub-metrics = lib.mkIf config.services.btrfs.autoScrub.enable {
    description = "Export the last btrfs scrub results to node_exporter (hourly)";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
    };
  };
}
