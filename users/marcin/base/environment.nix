# users/marcin/base/environment.nix
#
# Session-wide environment variables for marcin.
# Add variables here that must be available to every graphical and
# non-graphical session (they are written to ~/.profile by HM).
{pkgs, ...}: {
  home.sessionVariables = {
    # Required by the LanguageTool Emacs client to locate the JAR.
    LANGUAGETOOL_JAR = "${pkgs.languagetool}/share/languagetool-commandline.jar";

    # Make pkg-config find .pc files from Home Manager packages (poppler-glib etc.)
    # HM as NixOS module does not set up ~/.nix-profile; packages land in
    # /etc/profiles/per-user/marcin which is the active profile path.
    PKG_CONFIG_PATH = "/etc/profiles/per-user/marcin/lib/pkgconfig";
  };
}
