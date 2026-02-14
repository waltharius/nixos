# modules/laptop/thunderbolt-coldboot-fix.nix
{pkgs, ...}: {
  # Udev rule to fix cold boot DP issue
  services.udev.extraRules = ''
    # When Thunderbolt dock connects during boot without DP tunnel, force reset
    ACTION=="add", SUBSYSTEM=="thunderbolt", ENV{DEVTYPE}=="thunderbolt_device", \
    ATTR{vendor}=="0x108", ATTR{device}=="0x1630", \
    RUN+="${pkgs.bash}/bin/bash -c 'sleep 3 && /run/current-system/sw/bin/thunderbolt-dp-coldboot-fix'"
  '';

  # Script that checks and fixes DP tunnel
  environment.systemPackages = [
    (pkgs.writeScriptBin "thunderbolt-dp-coldboot-fix" ''
      #!/usr/bin/env bash

      # Wait for initialization to complete
      sleep 5

      # Check if this is port 0 and DP tunnel failed
      if [ -d "/sys/bus/thunderbolt/devices/0-1" ]; then
        # Check for torn-down DP tunnel in recent dmesg
        if dmesg | tail -100 | grep -q "not active, tearing down"; then
          echo "Cold boot DP tunnel failure detected, forcing controller reset..."

          # Method 1: Unbind/rebind the Thunderbolt controller
          TB_CONTROLLER=$(readlink -f /sys/bus/thunderbolt/devices/0-0)
          PCI_DEVICE=$(basename "$TB_CONTROLLER")

          echo "$PCI_DEVICE" > /sys/bus/pci/drivers/thunderbolt/unbind
          sleep 2
          echo "$PCI_DEVICE" > /sys/bus/pci/drivers/thunderbolt/bind

          # Wait for re-enumeration
          sleep 8

          # Trigger display rescan
          for drm in /sys/class/drm/card*/device/drm_dp_aux_dev; do
            [ -d "$drm" ] && echo 1 > /sys/class/drm/card*/device/driver/rescan || true
          done
        fi
      fi
    '')
  ];
}
