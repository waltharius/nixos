# LSP Configuration
{ pkgs, config, ... }:

let
  # Get home directory path for flake location
  homeDir = config.home.homeDirectory or "$HOME";
  flakePath = "${homeDir}/nixos";
in
{
  plugins.lsp = {
    enable = true;

    servers = {
      # Nix language server with dynamic configuration
      nixd = {
        enable = true;
        settings = {
          nixd = {
            formatting = {
              command = [ "alejandra" ];
            };
          };
        };
      };

      # Lua language server
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

  # Configure nixd options dynamically at runtime
  extraConfigLua = ''
    -- Configure nixd options dynamically based on hostname
    local home = vim.fn.expand('$HOME')
    local flakeDir = home .. '/nixos'
    local hostname = vim.fn.hostname()
    
    -- Update nixd settings after LSP starts
    vim.api.nvim_create_autocmd('LspAttach', {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == 'nixd' then
          -- Update nixd settings with dynamic values
          client.config.settings.nixd.nixpkgs = {
            expr = string.format('import (builtins.getFlake "%s").inputs.nixpkgs { }', flakeDir)
          }
          client.config.settings.nixd.options = {
            nixos = {
              expr = string.format('(builtins.getFlake "%s").nixosConfigurations.%s.options', flakeDir, hostname)
            }
          }
          -- Notify the server of config changes
          client.notify('workspace/didChangeConfiguration', { settings = client.config.settings })
        end
      end,
    })
  '';
}
