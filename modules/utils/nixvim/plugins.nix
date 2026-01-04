# Plugin Configuration
{pkgs, ...}: {
  plugins = {
    # Syntax highlighting
    treesitter = {
      enable = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
      };
      grammarPackages = pkgs.vimPlugins.nvim-treesitter.passthru.allGrammars;
    };

    # Code folding with UFO
    nvim-ufo = {
      enable = true;
      settings = {
        open_fold_hl_timeout = 5000;
        provider_selector = {
          __raw = ''
            function(bufnr, filetype, buftype)
              return {'treesitter', 'indent'}
            end
          '';
        };
      };
    };

    # Rainbow delimiters
    rainbow-delimiters.enable = true;

    # Indent guides
    indent-blankline = {
      enable = true;
      settings = {
        indent.char = "│";
        scope = {
          enabled = true;
          show_start = true;
          show_end = true;
        };
      };
    };

    # Mini.nvim for indentscope
    mini = {
      enable = true;
      modules = {
        indentscope = {
          draw = {
            delay = 0;
            animation.__raw = "require('mini.indentscope').gen_animation.none()";
          };
          symbol = "│";
          options = {
            try_as_border = true;
          };
        };
      };
    };

    # Telescope fuzzy finder
    telescope = {
      enable = true;
      extensions.fzf-native.enable = true;
      settings.defaults = {
        file_ignore_patterns = ["node_modules" ".git/"];
      };
    };

    # Git integration
    gitsigns = {
      enable = true;
      settings = {
        current_line_blame = true;
        current_line_blame_opts = {
          delay = 500;
          virt_text_pos = "eol";
        };
      };
    };

    # Neogit
    neogit = {
      enable = true;
      settings = {
        integrations = {
          telescope = true;
          diffview = true;
        };
        graph_style = "unicode";
      };
    };

    # Diffview
    diffview.enable = true;

    # Commenting
    comment.enable = true;

    # Auto pairs
    nvim-autopairs.enable = true;

    # Status line
    lualine = {
      enable = true;
      settings.options.theme = "auto";
    };

    # File tree
    neo-tree.enable = true;

    # Buffer line
    bufferline.enable = true;

    # Undo tree
    undotree.enable = true;

    # Web devicons
    web-devicons.enable = true;
  };

  # Custom highlight colors
  extraConfigLua = ''
    -- Indent guide colors
    vim.api.nvim_set_hl(0, "IblIndent", { fg = "#3b4261" })
    vim.api.nvim_set_hl(0, "IblScope", { fg = "#7aa2f7" })
    vim.api.nvim_set_hl(0, "MiniIndentscopeSymbol", { fg = "#bb9af7" })
  '';
}
