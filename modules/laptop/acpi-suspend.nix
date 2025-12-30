# ACPI daemon for hardware-level lid and power button handling
# Bypasses desktop environment inhibitors completely
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable ACPI daemon
  services.acpid = {
    enable = true;

    # Handle lid close events at hardware level
    lidEventCommands = ''
      # Get lid state
      LID_STATE=$(cat /proc/acpi/button/lid/LID*/state 2>/dev/null | awk '{print $2}')

      if [ "$LID_STATE" = "closed" ]; then
        logger "ACPI: Lid closed, triggering suspend-then-hibernate"
        systemctl suspend-then-hibernate
      fi
    '';

    # Handle power button events at hardware level
    powerEventCommands = ''
      logger "ACPI: Power button pressed, triggering suspend-then-hibernate"
      systemctl suspend-then-hibernate
    '';
  };
}
