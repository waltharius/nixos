# modules/home/shell/environment.nix
#
# Session environment variables shared by every Home Manager-managed user.
#
# WHAT BELONGS HERE:
#   - home.sessionVariables for variables needed by graphical apps launched
#     from GNOME (not just terminal shells) — e.g. SSH_ASKPASS, EDITOR
#
# WHAT DOES NOT BELONG HERE:
#   - Shell-only variables like PKG_CONFIG_PATH → those live in bash.nix
#     bashrcExtra so they are injected directly into ~/.bashrc, bypassing
#     the ~/.profile sourcing chain which is unreliable in non-login shells.
#   - User-specific variables (LANGUAGETOOL_JAR) → users/marcin/base/environment.nix
{ ... }: {
  # No shared session variables currently.
  # Add home.sessionVariables here when a variable must be visible to
  # graphical processes (not just bash), e.g.:
  #   home.sessionVariables.EDITOR = "nvim";
}
