{...}: {
  keymaps = [
    {
      mode = "n";
      key = "<leader>f";
      action = "<cmd>lua require('conform').format({ async = true, lsp_fallback = true })<CR>";
      options = {
        desc = "Format buffer";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ff";
      action = "<cmd>Telescope find_files<CR>";
      options = {
        desc = "Find files";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>fg";
      action = "<cmd>Telescope live_grep<CR>";
      options = {
        desc = "Live grep";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>fb";
      action = "<cmd>Telescope buffers<CR>";
      options = {
        desc = "Find buffers";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gs";
      action = "<cmd>Neogit<CR>";
      options = {
        desc = "Git status";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gc";
      action = "<cmd>Neogit commit<CR>";
      options = {
        desc = "Git commit";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gp";
      action = "<cmd>Neogit push<CR>";
      options = {
        desc = "Git push";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gl";
      action = "<cmd>Neogit log<CR>";
      options = {
        desc = "Git log";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>gb";
      action = "<cmd>lua require('gitsigns').toggle_current_line_blame()<CR>";
      options = {
        desc = "Toggle Git Blame";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w>h";
      options.desc = "Left window";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w>j";
      options.desc = "Bottom window";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w>k";
      options.desc = "Top window";
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w>l";
      options.desc = "Right window";
    }
    {
      mode = "n";
      key = "<leader>w";
      action = "<cmd>w<CR>";
      options = {
        desc = "Save";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>q";
      action = "<cmd>q<CR>";
      options = {
        desc = "Quit";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>u";
      action = "<cmd>UndotreeToggle<CR>";
      options = {
        desc = "UndoTree";
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<leader>ns";
      action = "<cmd>set spell!<CR>";
      options = {
        desc = "Toggle spell";
        silent = true;
      };
    }
  ];
}
