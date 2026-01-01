{pkgs, ...}: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    plugins = with pkgs.vimPlugins; [
      # Theme related
      tokyonight-nvim

      # Formatting
      conform-nvim
      rainbow-delimiters-nvim
      indent-blankline-nvim

      # Completion framework
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      luasnip
      cmp_luasnip

      # Syntax highlighting
      nvim-treesitter.withAllGrammars
      nvim-ufo
      promise-async

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
        config = ''
          require('gitsigns').setup({
            current_line_blame = true,

            current_line_blame_opts = {
              delay = 500,
              virt_text_pos = 'eol', -- by default 'eol' (end of line) or 'right_align'
            },
          })
        '';
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
      undotree
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
        vim.opt.undofile = true

        vim.g.mapleader = " "

        -- ========================================
        -- THEME CONFIGURATION (TokyoNight)
        -- ========================================
        require("tokyonight").setup({
          style = "storm", -- The specific style used in your nix repo
          transparent = true, -- Matches your manual "bg=none" settings
          styles = {
            sidebars = "transparent",
            floats = "transparent",
          },
        })
        vim.cmd.colorscheme "tokyonight-night"

        -- ========================================
        -- FORMATTING (Conform.nvim)
        -- ========================================
        require('rainbow-delimiters.setup').setup { }

        local highlight = {
          "RainbowRed",
          "RainbowYellow",
          "RainbowBlue",
          "RainbowOrange",
          "RainbowGreen",
          "RainbowViolet",
          "RainbowCyan",
        }

        local hooks = require("ibl.hooks")
        hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
          vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
          vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
          vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
          vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
          vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
          vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
          vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })
        end)

        require("ibl").setup {
          indent = { highlight = highlight },

          scope = {
              enabled = true,
              show_start = true,
              show_end = true,
              highlight = { "Function", "Label" },
          },
        }

        vim.o.foldcolumn = '1'
        vim.o.foldlevel = 99
        vim.o.foldlevelstart = 99
        vim.o.foldenable = true

        require('ufo').setup({
          provider_selector = function(bufnr, filetype, buftype)
              return {'treesitter', 'indent'}
          end
        })

        require("conform").setup({
          formatters_by_ft = {
            -- Your primary languages
            python = { "black" },
            bash = { "shfmt" },
            sh = { "shfmt" },
            nix = { "alejandra" },

            -- Additional languages
            lua = { "stylua" },
            javascript = { "prettier" },
            typescript = { "prettier" },
            json = { "prettier" },
            yaml = { "prettier" },
            markdown = { "prettier" },
            html = { "prettier" },
            css = { "prettier" },
          },

      vim.o.foldcolumn = '1' -- Pokaż mały pasek z boku z trójkącikami do zwijania
      vim.o.foldlevel = 99   -- Domyślnie wszystko otwarte
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true

      require('ufo').setup({
          provider_selector = function(bufnr, filetype, buftype)
              return {'treesitter', 'indent'}
          end
      })

      -- Skróty klawiszowe do zwijania (standard Vima, ale warto znać)
      -- za - przełącz (zwiń/rozwiń) pod kursorem
      -- zR - rozwiń wszystko
      -- zM - zwiń wszystko

          -- ⚡ AUTOMATIC FORMAT ON SAVE ⚡
          format_on_save = {
            timeout_ms = 500,
            lsp_fallback = true,  -- Use LSP formatting if conform doesn't have a formatter
          },
        })

        -- Optional: Manual format keybinding (in case you want to format without saving)
        vim.keymap.set('n', '<leader>f', function()
          require("conform").format({ async = true, lsp_fallback = true })
        end, { desc = "Format buffer" })

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

        -- ==========================================
        -- Undotree Keybinding
        -- ==========================================
        vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle, { desc = "Toggle UndoTree" })

        -- Optionally: shortcut to disable Git Blame. Toggle between on and off.
        vim.keymap.set('n', '<leader>gb', function() require('gitsigns').toggle_current_line_blame() end, { desc = "Toggle Git Blame" })
    '';
  };
}
