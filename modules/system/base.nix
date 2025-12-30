{
  config,
  pkgs,
  lib,
  ...
}: {
  # Enable new python-based nixos-rebuild-ng command
  system.rebuild.enableNg = true;
}
