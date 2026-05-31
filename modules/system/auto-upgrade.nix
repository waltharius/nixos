# Automatic system updates with meaningful generation names
{
  config,
  lib,
  pkgs,
  self,
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
          || true
      fi
    '';

    # Notify on upgrade failure
    onFailure = ["notify-upgrade-failure.service"];
  };

  # ---------------------------------------------------------------------------
  # Generation label visible in systemd-boot menu
  #
  # builtins.currentTime was removed from Nix (impure, non-deterministic).
  # Instead we use self.lastModified, which is the Unix timestamp of the
  # last git commit in the flake. After the preStart git commit above,
  # the next rebuild will have lastModified = time of that commit, so
  # the label accurately reflects when the auto-upgrade ran.
  #
  # base.nix sets lib.mkDefault with the git rev for manual rebuilds.
  # lib.mkForce here wins during automated nixos-upgrade runs.
  # ---------------------------------------------------------------------------
  system.nixos.label = lib.mkForce (
    let
      # self.lastModified is seconds since epoch of the last flake commit.
      # Convert to DD-MM-YYYY using string manipulation (pure Nix, no IFD).
      #
      # Nix doesn't have a date library, so we use a small derivation that
      # runs coreutils date at *build time* with the known epoch value.
      buildDate = builtins.readFile (
        pkgs.runCommand "build-date" {} ''
          echo -n $(${pkgs.coreutils}/bin/date -d @${toString self.lastModified} +%d-%m-%Y) > $out
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
