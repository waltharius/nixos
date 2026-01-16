# modules/home/desktop/gnome/extensions.nix
# GNOME extensions management

{lib, ...}: let
  cfg = config.programs.gnome-extensions;
in {
  options.programs.gnome-extensions = {
    enable =
      lib.mkEnableOption "GNOME extensions"
      // {
        default = true;
      };

    extensionPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "List of GNOME extension packages to install";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = cfg.extensionPackages;

    dconf.settings."org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = map (ext: ext.extensionUuid) cfg.extensionPackages;
      disabled-extensions = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
    };
  };
}
