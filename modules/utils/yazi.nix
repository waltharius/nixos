{pkgs, ...}: {
  programs.yazi = {
    enable = true;
    enableBashIntegration = true; # Auto-cd functionality
    package = pkgs.yazi;

    settings = {
      mgr = {
        ratio = [1 3 4];
        sort_by = "natural";
        sort_dir_first = true;
        show_hidden = true;
      };

      # Configure Vim as the editor
      opener = {
        edit = [
          {
            run = ''vim "$@"'';
            block = true; # Open in terminal
            desc = "Edit";
            for = "unix";
          }
        ];
      };

      # Force text files to use the 'edit' opener defined above
      open = {
        rules = [
          {
            name = "*/";
            use = ["edit" "open" "reveal"];
          }
          {
            mime = "text/*";
            use = ["edit" "reveal"];
          }
          {
            mime = "image/*";
            use = ["open" "reveal"];
          }
          {
            mime = "{audio,video}/*";
            use = ["play" "reveal"];
          }
          {
            mime = "inode/x-empty";
            use = ["edit" "reveal"];
          }
          {
            mime = "application/json";
            use = ["edit" "reveal"];
          }
        ];
      };
    };
  };

  # Ensure dependencies are available
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
