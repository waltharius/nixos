# modules/utils/yazi.nix
#
# Yazi terminal file manager.
#
# programs.yazi.shellWrapperName: in NixOS 26.05 the default shell wrapper
# was renamed from "yy" to "y" (a shorter, less conflicting name). The
# value is set explicitly here so that the behaviour is clear and no
# evaluation warning is emitted regardless of home.stateVersion.
{ pkgs, ... }: {
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    package = pkgs.yazi;
    shellWrapperName = "y";

    settings = {
      mgr = {
        ratio = [ 1 3 4 ];
        sort_by = "natural";
        sort_dir_first = true;
        show_hidden = true;
      };

      opener = {
        edit = [
          {
            run = ''vim "$@"'';
            block = true;
            desc = "Edit";
            for = "unix";
          }
        ];
      };

      open = {
        rules = [
          {
            name = "*/";
            use = [ "edit" "open" "reveal" ];
          }
          {
            mime = "text/*";
            use = [ "edit" "reveal" ];
          }
          {
            mime = "image/*";
            use = [ "open" "reveal" ];
          }
          {
            mime = "{audio,video}/*";
            use = [ "play" "reveal" ];
          }
          {
            mime = "inode/x-empty";
            use = [ "edit" "reveal" ];
          }
          {
            mime = "application/json";
            use = [ "edit" "reveal" ];
          }
        ];
      };
    };
  };

  home.packages = with pkgs; [
    file
    ffmpeg
    p7zip
    jq
    poppler-utils
    imagemagick
    chafa
    bat
    mediainfo
    exiftool
  ];
}
