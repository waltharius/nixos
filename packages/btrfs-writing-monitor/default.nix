{pkgs, ...}:
pkgs.writeShellApplication {
  name = "btrfs-writing-monitor";

  # Runtime dependencies — these are put on $PATH only while this script
  # runs, regardless of what's installed system-wide. This is the main
  # advantage of writeShellApplication over writeShellScriptBin: the script
  # can never silently fail on a missing command on some other host.
  runtimeInputs = with pkgs; [
    snapper
    compsize
    coreutils
    gawk
  ];

  # Keeping the script body in a separate .sh file (rather than inline as a
  # Nix multi-line string) avoids having to escape every ${...} bash
  # expansion as ''${...} to stop Nix from trying to interpolate it. This
  # mirrors the pattern already used in packages/track-package (lib.sh).
  text = builtins.readFile ./btrfs-writing-monitor.sh;
}
