# modules/laptop/acpi-fix.nix
# This module should prevent "interrupt storm" after succesfull wake up from sleep/hibernate
# It should also prevent freezing after hibernation with Thunderbolt docking station connected.
# Disable broken ACPI GPEs that cause interrupt storm (BIOS bug workaround)
# Fix ACPI interrupt storm (BIOS bug workaround)
{pkgs, ...}: let
  fixAcpiScript = pkgs.writeShellScript "fix-acpi-interrupts" ''
    # Disable GPE 0x61 (broken video display ID method)
    echo "disable" > /sys/firmware/acpi/interrupts/gpe61 2>/dev/null || true

    # Disable GPE 0xA7 (broken ACPI method)
    echo "disable" > /sys/firmware/acpi/interrupts/gpeA7 2>/dev/null || true

    # Log success
    logger "ACPI: Disabled buggy GPE 0x61 and 0xA7 to fix interrupt storm"
  '';
in {
  systemd.services.fix-acpi-interrupt-storm = {
    description = "Disable broken ACPI GPEs (BIOS bug workaround)";
    wantedBy = ["multi-user.target"];
    after = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${fixAcpiScript}";
    };
  };
}
