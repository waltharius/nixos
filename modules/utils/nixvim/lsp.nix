# LSP Configuration - Fully Dynamic
{ pkgs, config, lib, ... }:

let
  # Get the flake path from config option (falls back to ~/nixos)
  flakePath = config.programs.nixvim.flakePath;
  
  # Hostname interpolation for Lua (escaped properly)
  hostnameExpr = ''\${vim.fn.hostname()}'';
in
{
  programs.nixvim = {
    plugins.lsp = {
      enable = true;

      servers = {
        # Nix language server
        nixd = {
          enable = true;
          settings = {
            nixd = {
              formatting.command = [ "alejandra" ];
              
              # Nixpkgs expression using configurable flake path
              nixpkgs.expr = ''
                import (builtins.getFlake "${flakePath}").inputs.nixpkgs { }
              '';
              
              # NixOS options expression with proper escaping
              options.nixos.expr = ''
                (builtins.getFlake "${flakePath}").nixosConfigurations.${hostnameExpr}.options
              '';
            };
          };
        };

        # Lua language server
        lua_ls = {
          enable = true;
          settings.Lua.diagnostics.globals = [ "vim" ];
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
  };
}

