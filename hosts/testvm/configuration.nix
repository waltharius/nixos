# VM Test Configuration
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Hostname
  networking.hostName = "testvm";

  # VM-specific: Spice guest for better integration
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true;

  # VM-specific: No TLP (no battery in VM)
  services.tlp.enable = lib.mkForce false;

  # VM-specific: Disable WiFi (VM uses bridged/NAT networking)
  networking.networkmanager.wifi.enable = lib.mkForce false;

  # Basic user setup
  users.users.marcin = {
    isNormalUser = true;
    description = "Marcin";
    extraGroups = ["wheel" "networkmanager"];

    # SSH key (for testing)
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
    ];
  };

  # System version
  system.stateVersion = "25.11";
}
