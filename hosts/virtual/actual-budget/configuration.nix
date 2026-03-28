{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../../modules/servers/base-lxc.nix
    ../../../modules/servers/roles/actual-budget.nix
  ];

  networking.hostName = "actual-budget";
  system.stateVersion = "25.11";

  # Enable the role
  services.server-role.actual-budget = {
    enable = true;
    port = 5006;
    domain = "actual.home.lan";
  };
}
