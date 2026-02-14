# modules/laptop/thunderbolt.nix
{pkgs, ...}: {
  services.hardware.bolt.enable = true;

  environment.systemPackages = with pkgs; [
    bolt
  ];

  # Add systemd service to reinitialize Thunderbolt after resume
  systemd.services.thunderbolt-resume = {
    description = "Reinitialize Thunderbolt after resume";
    after = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];
    wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target"];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kmod}/bin/modprobe -r thunderbolt && ${pkgs.kmod}/bin/modprobe thunderbolt";
    };
  };

  # Ensure Thunderbolt devices are authorized on wake
  systemd.services.bolt-authorize-resume = {
    description = "Authorize Thunderbolt devices after resume";
    after = ["suspend.target" "hibernate.target"];
    wantedBy = ["suspend.target" "hibernate.target"];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.bolt}/bin/boltctl list | ${pkgs.gnugrep}/bin/grep -v authorized | ${pkgs.gawk}/bin/awk \"{print $1}\" | ${pkgs.findutils}/bin/xargs -I {} ${pkgs.bolt}/bin/boltctl authorize {}'";
    };
  };
}
