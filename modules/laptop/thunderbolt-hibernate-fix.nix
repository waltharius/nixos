# modules/laptop/thunderbolt-hibernate-fix.nix
# Fixes Thunderbolt dock power state corruption after hibernate
{pkgs, ...}: {
  # Script to unbind Thunderbolt devices before hibernate
  # and rebind them after resume
  systemd.services.thunderbolt-hibernate-prep = {
    description = "Prepare Thunderbolt for hibernate";
    before = ["systemd-hibernate.service" "systemd-suspend-then-hibernate.service"];
    wantedBy = ["hibernate.target" "suspend-then-hibernate.target"];

    script = ''
      echo "Thunderbolt hibernate prep: Saving dock state"
      # Force Thunderbolt controller to save state
      for tb in /sys/bus/thunderbolt/devices/*/authorized; do
        [ -f "$tb" ] && cat "$tb" > /tmp/tb-authorized-$(basename $(dirname $tb))
      done
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # Script to restore Thunderbolt state after resume
  systemd.services.thunderbolt-resume-fix = {
    description = "Fix Thunderbolt after hibernate resume";
    after = ["hibernate.target" "suspend-then-hibernate.target"];
    wantedBy = ["hibernate.target" "suspend-then-hibernate.target"];

    script = ''
      echo "Thunderbolt resume: Waiting for system stabilization"
      sleep 5

      # Force upower to re-detect power state
      ${pkgs.systemd}/bin/systemctl restart upower.service || true

      # Retrigger Thunderbolt discovery
      echo "Thunderbolt resume: Retriggering bolt service"
      ${pkgs.systemd}/bin/systemctl restart bolt.service || true

      # Give displays time to reconnect
      sleep 3

      # Force display manager to re-detect outputs
      if [ -n "$DISPLAY" ]; then
        echo "Thunderbolt resume: Forcing display refresh"
        ${pkgs.xorg.xrandr}/bin/xrandr --auto || true
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "45s";
    };
  };

  # Increase upower timeout for Thunderbolt dock power detection
  systemd.services.upower.serviceConfig = {
    TimeoutStartSec = "30s";
    Restart = "on-failure";
    RestartSec = "5s";
  };
}
