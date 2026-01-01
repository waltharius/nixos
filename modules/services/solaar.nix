{
  config,
  pkgs,
  ...
}: {
  hardware.logitech.wireless.enable = false;
  services.udev.packages = [pkgs.customPkgs.solaar-stable];
  environment.systemPackages = [pkgs.customPkgs.solar-stable];

  users.groups.plugdev = {};
}
