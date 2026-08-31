# users/marcin/base/git.nix
#
# Git identity and global settings for marcin.
# Kept separate so it can be reviewed and updated without touching
# anything else in the home configuration.
{ config, ... }: {
  programs.git = {
    enable = true;
    settings = {
      user.name  = "marcin";
      user.email = "nixosgitemail.frivolous320@passmail.net";
      init.defaultBranch = "main";
      # Always use SSH for GitHub pushes even when the remote URL uses HTTPS.
      url."git@github.com:".insteadOf = "https://github.com/";
    };

    # Repository-scoped settings.
    #
    # core.hooksPath is deliberately NOT in `settings' above. Set
    # globally it would apply to every repository on the machine, and
    # it REPLACES .git/hooks rather than adding to it — so any project
    # using husky, lefthook or the pre-commit framework would silently
    # stop running its own hooks. A conditional include keeps it to the
    # one repository that wants it.
    #
    # The `gitdir:' condition matches the .git directory and everything
    # under it, and the trailing slash is required for that.
    #
    # A RELATIVE hooksPath is resolved against the directory the hook
    # runs in, which for a normal worktree is its top level. So "hooks"
    # means ~/.emacs.d/hooks, and the scripts stay versioned in the
    # repository they check rather than living in .git/hooks, which is
    # per-clone and would exist on one machine only.
    includes = [
      {
        condition = "gitdir:${config.home.homeDirectory}/.emacs.d/";
        contents.core.hooksPath = "hooks";
      }
    ];
  };
}
