# modules/laptop/thunderbolt-coldboot-fix.nix
{pkgs, ...}: {
  systemd.services.thunderbolt-coldboot-fix = {
    description = "Wake up Thunderbolt dock DisplayPort after boot";
    wantedBy = ["multi-user.target"];
    after = ["multi-user.target" "bolt.service" "display-manager.service"];

    script = ''
      # Wait for system to stabilize
      sleep 8

      # Check if we're on port 0 (the problematic one)
      if [ -d "/sys/bus/thunderbolt/devices/0-1" ]; then
        echo "Thunderbolt dock detected on port 0"

        # Check if DP tunnel exists
        DP_ACTIVE=$(find /sys/bus/thunderbolt/devices -path "*/0-*/type" -exec grep -l "DP" {} \; 2>/dev/null | wc -l)

        if [ "$DP_ACTIVE" -eq 0 ]; then
          echo "No DisplayPort tunnel found, forcing wake-up cycle..."

          # Cycle the Thunderbolt authorization to force DP negotiation
          if [ -f "/sys/bus/thunderbolt/devices/0-1/authorized" ]; then
            echo 0 > /sys/bus/thunderbolt/devices/0-1/authorized
            sleep 3
            echo 1 > /sys/bus/thunderbolt/devices/0-1/authorized
            sleep 5

            # Trigger xrandr refresh for running sessions
            for session in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
              USER=$(loginctl show-session "$session" -p Name --value)
              DISPLAY=$(loginctl show-session "$session" -p Display --value)

              if [ -n "$DISPLAY" ]; then
                su - "$USER" -c "DISPLAY=$DISPLAY ${pkgs.xorg.xrandr}/bin/xrandr --auto" 2>/dev/null || true
              fi
            done
          fi
        else
          echo "DisplayPort tunnel already active"
        fi
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "30s";
    };
  };
}
