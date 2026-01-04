# Org-mode Configuration
{pkgs, ...}: {
  programs.nixvim = {
    plugins.orgmode = {
      enable = true;
      settings = {
        org_agenda_files = ["~/notes/org/**/*"];
        org_default_notes_file = "~/notes/org/refile.org";
      };
    };

    extraPackages = with pkgs; [
      aspell
      aspellDicts.en
      aspellDicts.pl
      hunspell
      hunspellDicts.en_US
      hunspellDicts.pl_PL
    ];

    extraConfigLua = ''
      -- Spell checking
      vim.opt.spell = true
      vim.opt.spelllang = { 'en_us', 'pl' }
      vim.opt.spellsuggest = 'best,10'

      -- Org file auto-settings
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'org',
        callback = function()
          vim.opt_local.spell = true
          vim.opt_local.spelllang = { 'en_us', 'pl' }
          vim.opt_local.textwidth = 80
          vim.opt_local.formatoptions:append('t')
          vim.opt_local.conceallevel = 2
          vim.opt_local.concealcursor = 'nc'

          -- Preserve format
          vim.opt_local.autoindent = false
          vim.opt_local.smartindent = false
          vim.opt_local.cindent = false
          vim.opt_local.indentexpr = ""
          vim.opt_local.fixendofline = false
        end
      })
    '';
  };
}
