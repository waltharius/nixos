{
  lib,
  config,
  ...
}: {
  options.programs.nixvim.flakePath = lib.mkOption {
    type = lib.types.str;
    # Don't reference config in default - use a placeholder
    default = ""; # Empty means auto-detect
    description = ''
      Path to your NixOS flake repository.
      If empty (default), will auto-detect from home directory.
    '';
    example = "/home/username/.config/nixos";
  };
}
