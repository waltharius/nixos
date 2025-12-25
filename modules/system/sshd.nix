# SSH Server (sshd) - Remote access configuration
# Secure configuration with key-based authentication only
{ config, lib, pkgs, ... }:

{
  # Enable OpenSSH daemon
  services.openssh = {
    enable = true;
    
    settings = {
      # Security: Only public key authentication
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      
      # Additional security
      X11Forwarding = false;
      AllowTcpForwarding = "yes";
      GatewayPorts = "no";
      
      # Performance
      UseDns = false;
    };
    
    # Listen on standard SSH port
    ports = [ 22 ];
  };
  
  # Open SSH port in firewall
  networking.firewall.allowedTCPPorts = [ 22 ];
}
