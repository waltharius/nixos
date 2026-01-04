# NixVim Configuration Module
# Drop-in replacement for modules/utils/neovim.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./core.nix
    ./plugins.nix
    ./lsp.nix
    ./completion.nix
    ./keymaps.nix
    ./formatting.nix
    ./org-mode.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
  };
}
