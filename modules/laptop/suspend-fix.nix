# ./modules/laptop/suspend-fix.nix
{pkgs, ...}: {
  # Disable all wakeup sources
  services.udev.extraRules = ''
    # Disable USB wakeup (dongle, dock USB ports)
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/wakeup}="disabled"

    # Disable PCI wakeup (Thunderbolt, dock controller)
    ACTION=="add", SUBSYSTEM=="pci", ATTR{power/wakeup}="disabled"
  '';

  #  # Override logind to properly detect AC power state
  #  systemd.services.fix-logind-ac-detection = {
  #    description = "Ensure logind detects AC power correctly";
  #    wantedBy = ["multi-user.target"];
  #    after = ["systemd-logind.service"];
  #
  #    serviceConfig = {
  #      Type = "oneshot";
  #      RemainAfterExit = true;
  #    };
  #
  #    script = ''
  #      # Restart logind to re-read config
  #      ${pkgs.systemd}/bin/systemctl restart systemd-logind.service
  #      ${pkgs.util-linux}/bin/logger "Logind restarted to ensure AC power detection"
  #    '';
  #  };
}
