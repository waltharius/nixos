# Home Manager configuration for user marcin
# Combines configuration from both previous setups
{ config, pkgs, lib, ... }:

let
  # Dotfiles symlink helper
  dotfiles = "${config.home.homeDirectory}/nixos-dotfiles/config";
  nixos-fonts = "${config.home.homeDirectory}/nixos-dotfiles/fonts";
  create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
in
{
  # ========================================
  # SOPS Configuration
  # ========================================
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets/ssh.yaml;
  };

  home.username = "marcin";
  home.homeDirectory = "/home/marcin";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # ========================================
  # IMPORTS - Additional modules
  # ========================================
  imports = [
    ../../modules/services/syncthing.nix
    ../../modules/services/ssh.nix
  ];

  # ========================================
  # GIT Configuration (FIXED - new syntax)
  # ========================================
  programs.git = {
    enable = true;
    userName = "marcin";
    
    # FIXED: Use programs.git.settings instead of userEmail
    settings = {
      user.email = "nixosgitemail.frivolous320@passmail.net";
      init.defaultBranch = "main";
      url."git@github.com:".insteadOf = "https://github.com/";
    };
  };

  # ========================================
  # FONTS
  # ========================================
  fonts.fontconfig.enable = true;
  
  # Optional: Symlink custom fonts if directory exists
  home.file.".local/share/fonts/custom" = lib.mkIf (builtins.pathExists nixos-fonts) {
    source = create_symlink nixos-fonts;
    recursive = true;
  };

  # ========================================
  # XDG CONFIG - External dotfiles
  # ========================================
  # Use external nvim config if it exists, otherwise use inline config
  xdg.configFile."nvim" = lib.mkIf (builtins.pathExists "${dotfiles}/nvim") {
    source = create_symlink "${dotfiles}/nvim/";
    recursive = true;
  };

  xdg.configFile."alacritty" = lib.mkIf (builtins.pathExists "${dotfiles}/alacritty") {
    source = create_symlink "${dotfiles}/alacritty/";
    recursive = true;
  };

  # ========================================
  # EMACS Configuration
  # ========================================
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;
  };

  # ========================================
  # NEOVIM Configuration (MERGED + FIXED)
  # ========================================
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    plugins = with pkgs.vimPlugins; [
      # Completion framework
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      luasnip
      cmp_luasnip

      # Syntax highlighting
      (nvim-treesitter.withPlugins (plugins:
        with plugins; [
          nix
          lua
          bash
          python
          markdown
          yaml
          json
        ]))

      # LSP Configuration - FIXED: Use new vim.lsp.config API
      {
        plugin = nvim-lspconfig;
        type = "lua";
        config = ''
          -- Nixd LSP (Nix language server)
          vim.lsp.config.nixd = {
            cmd = { "nixd" },
            filetypes = { "nix" },
            root_markers = { "flake.nix", ".git" },
            settings = {
              nixd = {
                formatting = {
                  command = { "alejandra" },
                },
                nixpkgs = {
                  expr = 'import (builtins.getFlake "/home/marcin/nixos").inputs.nixpkgs { }',
                },
                options = {
                  nixos = {
                    expr = '(builtins.getFlake "/home/marcin/nixos").nixosConfigurations.' .. vim.fn.hostname() .. '.options',
                  },
                },
              },
            },
          }
          vim.lsp.enable('nixd')

          -- Lua LSP
          vim.lsp.config.lua_ls = {
            cmd = { "lua-language-server" },
            filetypes = { "lua" },
            root_markers = { ".luarc.json", ".git" },
            settings = {
              Lua = {
                diagnostics = {
                  globals = { 'vim' },
                },
              },
            },
          }
          vim.lsp.enable('lua_ls')
        '';
      }

      # Telescope fuzzy finder
      {
        plugin = telescope-nvim;
        type = "lua";
        config = ''
          require('telescope').setup({
            defaults = {
              file_ignore_patterns = { "node_modules", ".git/" },
            },
          })
        '';
      }
      telescope-fzf-native-nvim
      plenary-nvim

      # Git integration
      {
        plugin = gitsigns-nvim;
        type = "lua";
        config = ''require('gitsigns').setup()'';
      }

      # Commenting
      {
        plugin = comment-nvim;
        type = "lua";
        config = ''require('Comment').setup()'';
      }

      # Auto pairs
      {
        plugin = nvim-autopairs;
        type = "lua";
        config = ''require('nvim-autopairs').setup({})'';
      }

      # Status line
      {
        plugin = lualine-nvim;
        type = "lua";
        config = ''require('lualine').setup({ options = { theme = 'auto' } })'';
      }

      # File tree
      neo-tree-nvim
      bufferline-nvim
      nvim-web-devicons
    ];

    extraPackages = with pkgs; [
      # LSP servers
      nixd
      lua-language-server
      
      # Formatters
      alejandra
      stylua
      black
      nodePackages.prettier
      shfmt
      
      # Tools
      ripgrep
      fd
      gcc
      nodejs
      python313Packages.pynvim
    ];

    extraLuaConfig = ''
      -- ==========================================
      -- Basic Settings
      -- ==========================================
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.expandtab = true
      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.termguicolors = true
      vim.opt.cursorline = true
      vim.opt.signcolumn = "yes"
      vim.opt.scrolloff = 8

      vim.g.mapleader = " "

      -- Colorscheme
      vim.cmd('colorscheme desert')

      -- ==========================================
      -- LSP Keybindings
      -- ==========================================
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(ev)
          local opts = { buffer = ev.buf }
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          vim.keymap.set('n', '<leader>f', function()
            vim.lsp.buf.format({ async = true })
          end, opts)
          vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
          vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
        end,
      })

      -- ==========================================
      -- Completion Setup
      -- ==========================================
      local cmp = require('cmp')
      local luasnip = require('luasnip')

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<Tab>'] = cmp.mapping.select_next_item(),
          ['<S-Tab>'] = cmp.mapping.select_prev_item(),
          ['<C-n>'] = cmp.mapping.select_next_item(),
          ['<C-p>'] = cmp.mapping.select_prev_item(),
        }),
        -- Source priority: LSP first
        sources = cmp.config.sources({
          { name = 'nvim_lsp', priority = 1000 },
          { name = 'luasnip', priority = 750 },
          { name = 'path', priority = 500 },
          { name = 'buffer', priority = 250 },
        }),
        -- Show source in completion menu
        formatting = {
          format = function(entry, vim_item)
            vim_item.menu = ({
              nvim_lsp = '[LSP]',
              luasnip = '[Snip]',
              buffer = '[Buf]',
              path = '[Path]',
            })[entry.source.name]
            return vim_item
          end,
        },
      })

      -- ==========================================
      -- Telescope Keybindings
      -- ==========================================
      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<leader>ff', builtin.find_files)
      vim.keymap.set('n', '<leader>fg', builtin.live_grep)
      vim.keymap.set('n', '<leader>fb', builtin.buffers)

      -- ==========================================
      -- Window Navigation
      -- ==========================================
      vim.keymap.set('n', '<C-h>', '<C-w>h')
      vim.keymap.set('n', '<C-j>', '<C-w>j')
      vim.keymap.set('n', '<C-k>', '<C-w>k')
      vim.keymap.set('n', '<C-l>', '<C-w>l')

      -- ==========================================
      -- Save and Quit
      -- ==========================================
      vim.keymap.set('n', '<leader>w', ':w<CR>')
      vim.keymap.set('n', '<leader>q', ':q<CR>')
    '';
  };

  # ========================================
  # TMUX Configuration
  # ========================================
  programs.tmux = {
    enable = true;
    mouse = true;
    escapeTime = 0;
    historyLimit = 1000000;
    baseIndex = 1;
    terminal = "tmux-256color";
    
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '5'
        '';
      }
    ];
  };

  # ========================================
  # BASH Configuration
  # ========================================
  programs.bash = {
    enable = true;

    shellAliases = {
      # Enhanced ls with eza
      ls = "eza --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git";
      ll = "eza -alF --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git";
      la = "eza -a --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git";
      lt = "eza --tree --hyperlink --group-directories-first --color=auto --icons --git";
      
      # Git shortcuts
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      
      # NixOS shortcuts
      nrs = "sudo nixos-rebuild switch --flake ~/nixos";
      nrt = "sudo nixos-rebuild test --flake ~/nixos";
      nrb = "sudo nixos-rebuild boot --flake ~/nixos";
      
      # WiFi management (NetworkManager)
      wifi-list = "nmcli device wifi list";
      wifi-connect = "nmcli device wifi connect";
      wifi-status = "nmcli connection show --active";
      wifi-forget = "nmcli connection delete";
      wifi-scan = "nmcli device wifi rescan";
      
      # Atuin filter modes
      atuin-local = "ATUIN_FILTER_MODE=host atuin search -i";
      atuin-global = "ATUIN_FILTER_MODE=global atuin search -i";
    };

    bashrcExtra = ''
      # Enhanced ls function
      lk() {
        ${pkgs.eza}/bin/eza -alF --hyperlink --group-directories-first --color=auto --color-scale=size --color-scale-mode=gradient --icons --git "$@"
      }

      # Load ble.sh if available
      if [[ -f ${pkgs.blesh}/share/blesh/ble.sh ]]; then
        source ${pkgs.blesh}/share/blesh/ble.sh --noattach
      fi

      # Atuin integration
      if command -v atuin &> /dev/null; then
        eval "$(${pkgs.atuin}/bin/atuin init bash)"
      fi

      # Zoxide integration
      if command -v zoxide &> /dev/null; then
        eval "$(${pkgs.zoxide}/bin/zoxide init bash)"
      fi

      # Attach ble.sh after integrations
      [[ ''${BLE_VERSION-} ]] && ble-attach || true

      # Yazi shell wrapper for cd on exit
      if command -v yazi &> /dev/null; then
        function y() {
          local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
          yazi "$@" --cwd-file="$tmp"
          if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
          fi
          rm -f -- "$tmp"
        }
      fi
    '';
  };

  # ========================================
  # STARSHIP - Cross-shell Prompt
  # ========================================
  programs.starship = {
    enable = true;
    enableBashIntegration = true;

    settings = {
      add_newline = false;

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };

      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
        style = "bold cyan";
      };

      git_branch = {
        symbol = "";
        style = "bold purple";
      };

      nix_shell = {
        symbol = " ";
        format = "[$symbol$state( ($name))]($style) ";
        style = "bold blue";
      };
    };
  };

  # ========================================
  # ZOXIDE - Smarter cd
  # ========================================
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    options = [ "--cmd cd" ];
  };

  # ========================================
  # ATUIN - Shell History Sync
  # ========================================
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;

    settings = {
      # Your self-hosted server
      sync_address = "https://atuin.home.lan";
      auto_sync = true;
      sync_frequency = "1m";
      
      # Filter by host by default
      filter_mode = "host";
      
      # Search settings
      search_mode = "fuzzy";
      style = "compact";
      show_preview = true;
      
      # Smart Up arrow - filter by directory
      filter_mode_shell_up_key_binding = "directory";
      
      # Privacy - never save sensitive commands
      history_filter = [
        "^pass"
        "^password"
        "^secret"
        "^atuin login"
      ];
    };
  };

  # ========================================
  # HOME PACKAGES
  # ========================================
  home.packages = with pkgs; [
    # GUI Applications
    blanket
    signal-desktop
    brave
    
    # Productivity & Office
    libreoffice-fresh      # Office suite
    zotero                 # Reference manager
    obsidian               # Knowledge management
    
    # Media & Entertainment
    spotify                # Music streaming
    spotify-player         # Terminal Spotify client
    
    # Development tools
    ripgrep
    fd
    tree
    wget
    curl
    git
    
    # Shell utilities
    blesh
    eza
    zoxide
    starship
    fastfetch
    atuin
    btop
    
    # Nix tools
    nix-prefetch-github
    sops
    age
    nil
    nixpkgs-fmt
    
    # File managers
    yazi
    
    # Fonts
    nerd-fonts.hack
    nerd-fonts.jetbrains-mono
    google-fonts
    liberation_ttf
    
    # Language tools
    hunspell
    hunspellDicts.en_GB-large
    hunspellDicts.pl_PL
    languagetool
    
    # GNOME Extensions
    gnomeExtensions.run-or-raise
    gnomeExtensions.gsconnect
    gnomeExtensions.just-perfection
  ];

  # ========================================
  # ENVIRONMENT VARIABLES
  # ========================================
  home.sessionVariables = {
    DICPATH = "${pkgs.hunspellDicts.en_GB-large}/share/hunspell:${pkgs.hunspellDicts.pl_PL}/share/hunspell";
    LANGUAGETOOL_JAR = "${pkgs.languagetool}/share/languagetool-commandline.jar";
    EMACS_NOTES_DIR = "$HOME/Notes";
  };

  # ========================================
  # GNOME CONFIGURATION
  # ========================================
  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "run-or-raise@edvard.cz"
        "gsconnect@andyholmes.github.io"
        "just-perfection-desktop@just-perfection"
      ];
    };
  };

  # Run-or-raise shortcuts
  xdg.configFile."run-or-raise/shortcuts.conf".text = ''
    <Control><Alt>e,${pkgs.emacs}/bin/emacs,emacs
    <Super>f,${pkgs.brave}/bin/brave,,
    <Super>e,nautilus,nautilus
    <Super>t,ptyxis
  '';
}
