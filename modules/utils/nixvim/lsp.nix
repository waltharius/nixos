# LSP Configuration
{ pkgs, ... }:

{
  plugins.lsp = {
    enable = true;

    servers = {
      nixd.enable = true;
      lua_ls = {
        enable = true;
        settings.Lua.diagnostics.globals = [ "vim" ];
      };
    };

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
    -- Get home directory and construct flake path
    local home = vim.fn.expand('$HOME')
    local flakeDir = home .. '/nixos'
    
    require('lspconfig').nixd.setup({
      cmd = { "nixd" },
      settings = {
        nixd = {
          formatting = {
            command = { "alejandra" },
          },
          nixpkgs = {
            expr = 'import (builtins.getFlake "' .. flakeDir .. '").inputs.nixpkgs { }',
          },
          options = {
            nixos = {
              expr = '(builtins.getFlake "' .. flakeDir .. '").nixosConfigurations.' .. vim.fn.hostname() .. '.options',
            },
          },
        },
      },
    })
  '';
}
