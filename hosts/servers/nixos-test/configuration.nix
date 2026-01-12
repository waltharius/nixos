{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../../modules/servers/base-lxc.nix
  ];

  # Host-specific settings only
  networking.hostName = "nixos-test";

  system.stateVersion = "25.11";

  # Override base settings if needed (optional)
  # Example: Add container-specific packages
  # environment.systemPackages = with pkgs; [
  #   docker
  # ];

  # Example: Open additional ports
  # networking.firewall.allowedTCPPorts = [80 443];
}
