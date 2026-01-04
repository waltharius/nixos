# Formatting Configuration
{pkgs, ...}: {
  programs.nixvim = {
    plugins.conform-nvim = {
      enable = true;
      settings = {
        formatters_by_ft = {
          python = ["black"];
          bash = ["shfmt"];
          sh = ["shfmt"];
          nix = ["alejandra"];
          lua = ["stylua"];
          javascript = ["prettier"];
          typescript = ["prettier"];
          json = ["prettier"];
          yaml = ["prettier"];
          markdown = ["prettier"];
          html = ["prettier"];
          css = ["prettier"];
        };

        format_on_save = {
          timeout_ms = 500;
          lsp_fallback = true;
        };
      };
    };

    extraPackages = with pkgs; [
      alejandra
      stylua
      black
      nodePackages.prettier
      shfmt
    ];
  };
}
