# Automatic system updates with meaningful generation names
{
  config,
  pkgs,
  ...
}: {
  # Allow root to access user's git repository
  environment.etc."gitconfig".text = ''
    [safe]
      directory = /home/marcin/nixos
  '';

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
      "home-manager"
      "--commit-lock-file" # Commit the updated flake.lock
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

  # Keep more generations for safety
  nix.gc = {
    automatic = true;
    dates = "monthly"; # Clean up monthly, not too aggressive
    options = "--delete-older-than 90d"; # Keep 3 months of generations
  };

  # Optimize store after garbage collection
  nix.optimise = {
    automatic = true;
    dates = ["weekly"]; # Run after auto-upgrade
  };

  # === NOTIFICATIONS WITH CHANGELOG ===

  # Install required tools
  environment.systemPackages = with pkgs; [
    nvd # Nix Version Diff - shows package changes
  ];

  # Success notification with changelog
  systemd.services.nixos-upgrade-notify-success = {
    description = "Notify about successful NixOS upgrade with changelog";
    after = ["nixos-upgrade.service"];
    wants = ["nixos-upgrade.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      User = "marcin";
      Environment = [
        "DISPLAY=:0"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
      ];
    };

    # Run only if upgrade succeeded
    unitConfig.ConditionPathExists = "/var/lib/nixos-upgrade-success";

    script = ''
      # Get generation numbers
      CURRENT_GEN=$(${pkgs.nix}/bin/nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -1 | ${pkgs.gawk}/bin/awk '{print $1}')
      PREVIOUS_GEN=$((CURRENT_GEN - 1))

      # Generate changelog
      CHANGELOG=$(${pkgs.nvd}/bin/nvd diff \
      /nix/var/nix/profiles/system-$PREVIOUS_GEN-link \
      /nix/var/nix/profiles/system-$CURRENT_GEN-link)

      # Count changes
      UPDATED=$(echo "$CHANGELOG" | grep -c "→" || echo "0")
      ADDED=$(echo "$CHANGELOG" | grep -c "^[^→]*:" | ${pkgs.gawk}/bin/awk '{print $1/2}' || echo "0")

      # Send notification
      ${pkgs.libnotify}/bin/notify-send \
        --urgency=normal \
        --icon=system-software-update \
        --app-name="NixOS" \
        "System Upgraded ✓" \
        "Generation #$CURRENT_GEN

      $UPDATED packages updated
      $ADDED packages added

      Run 'nvd diff /nix/var/nix/profiles/system-{$PREVIOUS_GEN,$CURRENT_GEN}-link' for details"

      # Clean up marker
      rm -f /var/lib/nixos-upgrade-success
    '';
  };

  # Failure notification
  systemd.services.nixos-upgrade-notify-failure = {
    description = "Notify about failed NixOS upgrade";
    after = ["nixos-upgrade.service"];
    wants = ["nixos-upgrade.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      User = "marcin";
      Environment = [
        "DISPLAY=:0"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
      ];
    };

    # Run only if upgrade failed
    unitConfig.ConditionPathExists = "!/var/lib/nixos-upgrade-success";

    script = ''
      # Get error from journal
      ERROR=$(${pkgs.systemd}/bin/journalctl -u nixos-upgrade.service -n 20 --no-pager | tail -10)

      ${pkgs.libnotify}/bin/notify-send \
        --urgency=critical \
        --icon=dialog-error \
        --app-name="NixOS" \
        "System Upgrade Failed ✗" \
        "Check logs: sudo journalctl -u nixos-upgrade.service"
    '';
  };

  # Create success marker after upgrade
  systemd.services.nixos-upgrade = {
    postStop = ''
      if [ $SERVICE_RESULT = "success" ]; then
        touch /var/lib/nixos-upgrade-success
      fi
    '';
  };
}
