# NixVim Configuration Module
# Drop-in replacement for modules/utils/neovim.nix
{...}: {
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Import all sub-configurations
    imports = [
      ./options.nix
      ./core.nix
      ./plugins.nix
      ./lsp.nix
      ./completion.nix
      ./keymaps.nix
      ./formatting.nix
      ./org-mode.nix
    ];
  };
}
