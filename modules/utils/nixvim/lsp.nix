{
  pkgs,
  config,
  ...
}: let
  # If flakePath is empty, default to ~/nixos
  flakePath =
    if config.programs.nixvim.flakePath == ""
    then "${config.home.homeDirectory}/nixos"
    else config.programs.nixvim.flakePath;
in {
  plugins.lsp = {
    enable = true;

    servers = {
      nixd.enable = true;
      lua_ls = {
        enable = true;
        settings.Lua.diagnostics.globals = ["vim"];
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

  extraConfigLua = ''
    local flakeDir = vim.fn.expand('${flakePath}')

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
