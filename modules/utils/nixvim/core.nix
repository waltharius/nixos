# Core Neovim Settings
{...}: {
  globals.mapleader = " ";

  # Editor options
  opts = {
    number = true;
    relativenumber = true;
    expandtab = true;
    tabstop = 2;
    shiftwidth = 2;
    termguicolors = true;
    cursorline = true;
    signcolumn = "yes";
    scrolloff = 8;
    undofile = true;

    # Folding settings
    foldcolumn = "1";
    foldlevel = 99;
    foldlevelstart = 99;
    foldenable = true;
  };

  # Colorscheme configuration
  colorschemes.tokyonight = {
    enable = true;
    settings = {
      style = "storm";
      transparent = true;
      styles = {
        sidebars = "transparent";
        floats = "transparent";
      };
    };
  };

  # Apply night variant
  extraConfigLua = ''
    vim.cmd.colorscheme "tokyonight-night"
  '';
}
