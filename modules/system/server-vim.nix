# Lightweight vim configuration for servers (no home-manager needed)
{pkgs, ...}: {
  # Install vim system-wide
  environment.systemPackages = with pkgs; [
    vim
  ];

  # Set vim as default editor
  environment.variables.EDITOR = "vim";

  # Create a shared vimrc for all users
  environment.etc."vimrc".text = ''
    " Basic vim configuration for NixOS servers

    " Enable syntax highlighting
    syntax on

    " Enable line numbers
    set number
    set relativenumber

    " Enable mouse support
    set mouse=a

    " Set tabs to 2 spaces
    set tabstop=2
    set shiftwidth=2
    set expandtab

    " Enable incremental search
    set incsearch
    set hlsearch

    " Show matching brackets
    set showmatch

    " Enable filetype detection
    filetype plugin indent on

    " Better color scheme for terminal
    colorscheme desert

    " Show current position
    set ruler

    " Enable command completion
    set wildmenu
    set wildmode=longest:full,full

    " Keep undo history
    set undofile
    set undodir=/tmp/vim-undo

    " Auto-create undo directory if it doesn't exist
    silent !mkdir -p /tmp/vim-undo
  '';
}
