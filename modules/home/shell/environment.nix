# modules/home/shell/environment.nix
#
# Session environment variables shared by every Home Manager-managed user.
# Variables that belong here:
#   - Variables needed by any user who has a HM profile (PKG_CONFIG_PATH)
#   - Tool integrations that are enabled for all users (SSH_ASKPASS)
# Variables that do NOT belong here:
#   - Variables referencing user-specific packages (LANGUAGETOOL_JAR → marcin only)
#   - Variables referencing user-specific paths or secrets
{config, ...}: {
  programs.bash.sessionVariables = {
    PKG_CONFIG_PATH = "/etc/profiles/per-user/${config.home.username}/lib/pkgconfig";
  };
}
