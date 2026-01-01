{
  config,
  pkgs,
  ...
}: {
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true; # Installing solaar package with GUI
}
