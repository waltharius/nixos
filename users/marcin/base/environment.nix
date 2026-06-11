# users/marcin/base/environment.nix
#
# Session-wide environment variables for marcin.
# Add variables here that must be available to every graphical and
# non-graphical session (they are written to ~/.profile by HM).
{pkgs, ...}: {
  home.sessionVariables = {
    # Required by the LanguageTool Emacs client to locate the JAR.
    LANGUAGETOOL_JAR = "${pkgs.languagetool}/share/languagetool-commandline.jar";
  };
}
