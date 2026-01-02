# Modular Org-Mode Configuration for Neovim
# This module can be safely removed without affecting core Neovim functionality
# Compatible with Emacs org files - no format changes
{pkgs, ...}: {
  programs.neovim = {
    plugins = with pkgs.vimPlugins; [
      # Org-mode support
      {
        plugin = orgmode;
        type = "lua";
        config = ''          
          -- Load org-mode configuration from external file
          dofile('${./lua/org-mode-denote.lua}')
        '';
      }
    ];

    # Additional packages for org-mode functionality
    extraPackages = with pkgs; [
      # Spell checking
      aspell
      aspellDicts.en
      aspellDicts.pl
      hunspell
      hunspellDicts.en_US
      hunspellDicts.pl_PL
    ];

    extraLuaConfig = ''
      -- ========================================
      -- SPELL CHECKING (English + Polish)
      -- ========================================

      vim.opt.spell = true
      vim.opt.spelllang = { 'en_us', 'pl' }
      vim.opt.spellsuggest = 'best,10'

      -- Auto-enable spell check for org files
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'org',
        callback = function()
          vim.opt_local.spell = true
          vim.opt_local.spelllang = { 'en_us', 'pl' }
          -- Auto-wrap at 80 columns (like Emacs auto-fill)
          vim.opt_local.textwidth = 80
          vim.opt_local.formatoptions:append('t')
          
          -- Enable concealment for prettier display
          vim.opt_local.conceallevel = 2
          vim.opt_local.concealcursor = 'nc'
        end
      })

      -- Spell check keybindings
      vim.keymap.set('n', '<leader>ns', ':set spell!<CR>', { desc = 'Toggle spell check' })
      vim.keymap.set('n', 'z=', 'z=', { desc = 'Spelling suggestions' })
      vim.keymap.set('n', 'zg', 'zg', { desc = 'Add word to dictionary' })
      vim.keymap.set('n', 'zw', 'zw', { desc = 'Mark word as wrong' })

      -- ========================================
      -- ORG FILE SETTINGS (Preserve format)
      -- ========================================

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'org',
        callback = function()
          -- Disable auto-indent to preserve org structure
          vim.opt_local.autoindent = false
          vim.opt_local.smartindent = false
          vim.opt_local.cindent = false

          -- Preserve whitespace
          vim.opt_local.expandtab = true
          vim.opt_local.tabstop = 2
          vim.opt_local.shiftwidth = 2

          -- Don't add extra newlines
          vim.opt_local.fixendofline = false
        end
      })
    '';
  };
}
