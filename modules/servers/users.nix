# Server user management
# Defines nixadm user for server administration
# Used on all servers instead of direct root login

{ config, lib, pkgs, ... }: {
  # Disable root SSH login for security
  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "no";
  };

  # Create dedicated admin user for servers
  users.users.nixadm = {
    isNormalUser = true;
    description = "NixOS Administrator";
    extraGroups = [ "wheel" ];  # Enable sudo
    
    # SSH key authentication only
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhyNxm4pZR9CCnWGlDA+jotcnH5sc53LpSkSLs7XNx0 walth@fedora-laptop-tabby-2025"
    ];
  };

  # Passwordless sudo for wheel group (nixadm)
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
}
