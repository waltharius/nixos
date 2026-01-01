{
  config,
  pkgs,
  customPkgs,
  ...
}: {
  hardware.logitech.wireless.enable = false;
  services.udev.packages = [customPkgs.solaar-stable];
  environment.systemPackages = [customPkgs.solaar-stable];

  users.groups.plugdev = {};
}
