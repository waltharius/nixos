# LSP Configuration - Fully Dynamic (Working Version)
{
  pkgs,
  config,
  ...
}: let
  # Get the flake path from config option
  flakePath = config.programs.nixvim.flakePath;
in {
  programs.nixvim = {
    plugins.lsp = {
      enable = true;

      servers = {
        # Nix language server - configured via extraConfigLua below
        nixd = {
          enable = true;
          # Don't set settings here - we'll do it in extraConfigLua
        };

        # Lua language server
        lua_ls = {
          enable = true;
          settings.Lua.diagnostics.globals = ["vim"];
        };
      };

      # LSP keybindings
      keymaps = {
        diagnostic = {
          "[d" = "goto_prev";
          "]d" = "goto_next";
        };
        lspBuf = {
          "gd" = "definition";
          "K" = "hover";
        };
      };
    };

    extraPackages = with pkgs; [
      nixd
      lua-language-server
    ];

    # Configure nixd dynamically with Lua
    extraConfigLua = ''
      -- Configure nixd LSP with dynamic hostname
      require('lspconfig').nixd.setup({
        cmd = { "nixd" },
        settings = {
          nixd = {
            formatting = {
              command = { "alejandra" },
            },
            nixpkgs = {
              expr = 'import (builtins.getFlake "${flakePath}").inputs.nixpkgs { }',
            },
            options = {
              nixos = {
                expr = '(builtins.getFlake "${flakePath}").nixosConfigurations.' .. vim.fn.hostname() .. '.options',
              },
            },
          },
        },
      })
    '';
  };
}
