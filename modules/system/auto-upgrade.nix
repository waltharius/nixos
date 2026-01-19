# Automatic system updates with meaningful generation names
{
  config,
  lib,
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
      "--commit-lock-file"
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

  # Notify on upgrade failure
  systemd.services.nixos-upgrade = {
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
