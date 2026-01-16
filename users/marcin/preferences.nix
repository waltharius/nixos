# users/marcin/preferences.nix
# Marcin's personal preferences (aliases, environment variables)
{...}: {
  # NOTE: More bash aliases are already in modules/home/shell/bash.nix
  # Add only personal overrides here if needed

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
