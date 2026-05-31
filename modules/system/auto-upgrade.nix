# Automatic system updates with meaningful generation names
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Automatic system upgrades
  system.autoUpgrade = {
    enable = true;

    # Use your flake for upgrades
    flake = "/home/marcin/nixos#${config.networking.hostName}";

    # Update inputs (nixpkgs, etc.) before upgrading
    flags = [
      "--update-input"
      "nixpkgs"
      "--update-input"
      "nixpkgs-unstable"
      "--update-input"
      "home-manager"
      "--update-input"
      "sops-nix"
      "--update-input"
      "nixvim"
    ];

    # When to run
    dates = "weekly"; # or "Sun *-*-* 03:00:00" for Sundays at 3 AM

    # Allow downgrades (useful if a channel has issues)
    allowReboot = false; # Set to true if you want automatic reboots after kernel updates

    # Run even if system was asleep during scheduled time
    persistent = true;

    # Randomize upgrade time within 1 hour window (reduces server load)
    randomizedDelaySec = "1h";
  };

  # ---------------------------------------------------------------------------
  # Pre-upgrade: git commit so the rebuild is never "dirty"
  #
  # nixos-rebuild marks a flake dirty when there are uncommitted changes in
  # the working tree. Running nix flake update (triggered by --update-input
  # above) rewrites flake.lock but does NOT auto-commit it, so the store path
  # ends up with ".dirty" appended. We fix this by committing flake.lock (and
  # any other tracked changes) before the rebuild happens.
  #
  # Risk: if the rebuild fails after this commit, the repo describes a
  # configuration the system hasn't activated yet. This is intentional —
  # the history remains accurate for forensics and rollback.
  # ---------------------------------------------------------------------------
  systemd.services.nixos-upgrade = {
    preStart = ''
      # Allow root to access the repo in the user's home directory
      ${pkgs.git}/bin/git config --global --add safe.directory /home/marcin/nixos

      # Commit flake.lock (and any other tracked changes) with today's date
      # so the subsequent rebuild sees a clean working tree.
      cd /home/marcin/nixos
      if ! ${pkgs.git}/bin/git diff --quiet || ! ${pkgs.git}/bin/git diff --cached --quiet; then
        UPGRADE_DATE=$(${pkgs.coreutils}/bin/date +%d-%m-%Y)
        ${pkgs.git}/bin/git add -A
        ${pkgs.git}/bin/git commit -m "system auto-upgrade $UPGRADE_DATE" \
          --author="NixOS Auto-Upgrade <auto-upgrade@${config.networking.hostName}>" \
          || true  # never abort the upgrade if commit fails (e.g. nothing changed)
      fi
    '';

    # Notify on upgrade failure
    onFailure = ["notify-upgrade-failure.service"];
  };

  # ---------------------------------------------------------------------------
  # Generation label visible in systemd-boot menu
  #
  # system.nixos.label sets the string shown in /boot/loader/entries/*.conf
  # as the boot entry title. systemd-boot displays it directly in the menu.
  #
  # base.nix sets a lib.mkDefault label with the git rev for manual rebuilds.
  # This lib.mkForce wins during automated nixos-upgrade runs and stamps
  # the build date instead.
  #
  # The label is evaluated at *build time* using builtins.currentTime
  # (seconds since epoch at Nix evaluation), converted to DD-MM-YYYY via
  # a small derivation. Every nixos-rebuild bakes the current date in.
  # ---------------------------------------------------------------------------
  system.nixos.label = lib.mkForce (
    let
      buildDate = builtins.readFile (
        pkgs.runCommand "build-date" {} ''
          echo -n $(${pkgs.coreutils}/bin/date -d @${toString builtins.currentTime} +%d-%m-%Y) > $out
        ''
      );
    in
      "auto-upgrade-${buildDate}"
  );

  systemd.services.notify-upgrade-failure = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getBin pkgs.libnotify}/bin/notify-send 'NixOS upgrade Failed!' 'Check journalctl -u nixos-upgrade'";
      User = "marcin";
      Environment = "DISPLAY=:0";
    };
  };

  # Keep more generations for safety
  nix.gc = {
    automatic = true;
    dates = "monthly"; # Clean up monthly, not too aggressive
    options = "--delete-older-than 90d"; # Keep 3 months of generations
  };

  # Optimize store after garbage collection
  nix.settings.auto-optimise-store = true;

  nix.optimise = {
    automatic = true;
    dates = ["weekly"]; # Run after auto-upgrade
  };
}
