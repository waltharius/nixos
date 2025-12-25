# SOPS secrets configuration
# This module sets up sops-nix for system-level secrets management
{ config, lib, pkgs, ... }:

{
  sops = {
    # Default secrets file location
    defaultSopsFile = ../../secrets/common.yaml;
    
    # Age key file location (host-specific private key)
    age.keyFile = "/var/lib/sops-nix/key.txt";
    
    # Define secrets that should be available to the system
    secrets = {
      # Example: User password (needed for user creation)
      # "user-password" = {
      #   neededForUsers = true;
      # };
    };
  };
}
