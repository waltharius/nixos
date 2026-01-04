# Options for nixvim configuration
{
  lib,
  config,
  ...
}: {
  options.programs.nixvim.flakePath = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/nixos";
    description = "Path to your NixOS flake repository";
    example = "${config.home.homeDirectory}/.config/nixos";
  };
}
