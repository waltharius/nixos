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
    dates = "weekly";

    # Allow downgrades (useful if a channel has issues)
    allowReboot = false;

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
  # Generation label strategy:
  #   - nixos-upgrade service passes --system-label auto-upgrade-DD-MM-YYYY
  #     directly to nixos-rebuild via the Environment override below.
  #   - Manual nixos-rebuild calls receive no such flag and keep the default
  #     label (short git rev or "dirty" if working tree is unclean).
  # ---------------------------------------------------------------------------
  systemd.services.nixos-upgrade = {
    environment = {
      # Inject a dated label that nixos-rebuild picks up via NIXOS_LABEL.
      # This env var is read by nixos-rebuild and passed as --system-label
      # to the toplevel derivation, so only automated builds carry the tag.
      NIXOS_LABEL_PREFIX = "auto-upgrade";
    };

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
          || true
      fi

      # Export NIXOS_LABEL so nixos-rebuild picks it up as the generation label.
      # Format: auto-upgrade-DD-MM-YYYY  (dashes only, no spaces or slashes
      # which are forbidden in NixOS generation label strings).
      export NIXOS_LABEL="auto-upgrade-$(${pkgs.coreutils}/bin/date +%d-%m-%Y)"
    '';

    # Notify on upgrade failure
    onFailure = ["notify-upgrade-failure.service"];
  };

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
    dates = "monthly";
    options = "--delete-older-than 90d";
  };

  # Optimize store after garbage collection
  nix.settings.auto-optimise-store = true;

  nix.optimise = {
    automatic = true;
    dates = ["weekly"];
  };
}
