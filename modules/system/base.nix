{
  config,
  pkgs,
  lib,
  ...
}: {
  # Enable new python-based nixos-rebuild-ng command
  system.rebuild.enableNg = true;
  users.groups.uinput = {};
  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
  '';
}
