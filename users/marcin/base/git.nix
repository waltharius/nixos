# users/marcin/base/git.nix
#
# Git identity and global settings for marcin.
# Kept separate so it can be reviewed and updated without touching
# anything else in the home configuration.
{ ... }: {
  programs.git = {
    enable = true;
    settings = {
      user.name  = "marcin";
      user.email = "nixosgitemail.frivolous320@passmail.net";
      init.defaultBranch = "main";
      # Always use SSH for GitHub pushes even when the remote URL uses HTTPS.
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };
}
