# Neovim Configuration Documentation

## Overview

This Neovim configuration provides a modern, feature-rich development environment optimized for Nix, Lua, Python, and web development. It includes LSP support, intelligent code completion, advanced formatting, and visual aids for code navigation.

### Key Features

- **Theme**: TokyoNight (storm/night variant) with transparency
- **LSP**: Nixd (Nix) and Lua Language Server with auto-formatting
- **Completion**: Context-aware with LSP, snippets, and path completion
- **Visual Aids**: Rainbow delimiters, indent guides, scope highlighting
- **Code Folding**: Treesitter-based with visual indicators
- **Git Integration**: Neogit (Magit-like), inline blame, and change indicators
- **Fuzzy Finding**: Telescope for files, grep, and buffer search

---

## Installed Plugins

### Theme and UI
- **tokyonight-nvim**: Dark theme with storm/night styles
- **lualine-nvim**: Status line with auto theme detection
- **nvim-web-devicons**: File type icons
- **bufferline-nvim**: Buffer/tab bar

### Code Editing
- **nvim-treesitter**: Syntax highlighting and AST-based features
- **conform-nvim**: Auto-formatting on save
- **comment-nvim**: Smart commenting (gcc, gbc)
- **nvim-autopairs**: Automatic bracket/quote pairing
- **rainbow-delimiters-nvim**: Colorful bracket pairs

### Visual Navigation
- **indent-blankline-nvim**: Indent guides with scope highlighting
- **mini.indentscope**: Current indent level highlighting
- **nvim-ufo**: Advanced code folding with treesitter

### Code Intelligence
- **nvim-lspconfig**: LSP client configuration
- **nvim-cmp**: Completion engine
  - **cmp-nvim-lsp**: LSP completion source
  - **cmp-buffer**: Buffer text completion
  - **cmp-path**: File path completion
  - **luasnip + cmp_luasnip**: Snippet support

### File Management
- **telescope-nvim**: Fuzzy finder for files, grep, buffers
- **telescope-fzf-native-nvim**: Native FZF sorting
- **neo-tree-nvim**: File explorer
- **undotree**: Visual undo history

### Git Integration
- **gitsigns-nvim**: Git change indicators and inline blame
- **neogit**: Interactive Git interface (Magit-like experience)
- **diffview-nvim**: Advanced diff viewer (required by Neogit)

### Language Servers & Formatters
- **nixd**: Nix language server
- **lua-language-server**: Lua LSP
- **alejandra**: Nix formatter
- **stylua**: Lua formatter
- **black**: Python formatter
- **prettier**: JavaScript/TypeScript/JSON/YAML/Markdown/HTML/CSS formatter
- **shfmt**: Bash/Shell script formatter

---

## Keybindings

### Leader Key

The leader key is set to **Space** (`<Space>`)

---

### File Operations

| Keybinding | Mode | Action | Description |
|------------|------|--------|--------------|
| `<leader>w` | Normal | `:w<CR>` | Save current file |
| `<leader>q` | Normal | `:q<CR>` | Quit current window/buffer |

---

### Telescope (Fuzzy Finder)

| Keybinding | Mode | Action | Description |
|------------|------|--------|--------------|
| `<leader>ff` | Normal | `find_files` | Find files in current directory |
| `<leader>fg` | Normal | `live_grep` | Search text in files (ripgrep) |
| `<leader>fb` | Normal | `buffers` | List and switch between open buffers |

---

### LSP (Language Server Protocol)

These keybindings are automatically available when LSP is attached to a buffer:

| Keybinding | Mode | Action | Description |
|------------|------|--------|--------------|  
| `gd` | Normal | `definition` | Go to definition |
| `K` | Normal | `hover` | Show hover documentation |
| `<leader>f` | Normal | `format` | Format current buffer (async) |
| `[d` | Normal | `goto_prev` | Go to previous diagnostic |
| `]d` | Normal | `goto_next` | Go to next diagnostic |

---

### Completion (Insert Mode)

| Keybinding | Mode | Action | Description |
|------------|------|--------|--------------|
| `<C-Space>` | Insert | Complete | Trigger completion menu |
| `<CR>` (Enter) | Insert | Confirm | Confirm selected completion |
| `<Tab>` | Insert | Next item | Select next completion item |
| `<S-Tab>` | Insert | Previous item | Select previous completion item |
| `<C-n>` | Insert | Next item | Select next completion item |
| `<C-p>` | Insert | Previous item | Select previous completion item |

---

### Window Navigation

| Keybinding | Mode | Action | Description |
|------------|------|--------|--------------|
| `<C-h>` | Normal | `<C-w>h` | Move to left window |
| `<C-j>` | Normal | `<C-w>j` | Move to bottom window |
| `<C-k>` | Normal | `<C-w>k` | Move to top window |
| `<C-l>` | Normal | `<C-w>l` | Move to right window |

---

### Code Folding

| Keybinding | Mode | Action | Description |
|------------|------|--------|--------------|
| `za` | Normal | Toggle fold | Toggle fold at cursor |
| `zR` | Normal | Open all folds | Expand all folds in buffer |
| `zM` | Normal | Close all folds | Collapse all folds in buffer |
| `zo` | Normal | Open fold | Open fold at cursor |
| `zc` | Normal | Close fold | Close fold at cursor |
| `zr` | Normal | Reduce folding | Expand one fold level |
| `zm` | Normal | More folding | Collapse one fold level |

---

### Git (Neogit - Magit-like Interface)

| Keybinding | Mode | Action | Description |
|------------|------|--------|--------------|  
| `<leader>gs` | Normal | `:Neogit<CR>` | Open Git status (main interface) |
| `<leader>gc` | Normal | `:Neogit commit<CR>` | Open commit menu |
| `<leader>gp` | Normal | `:Neogit push<CR>` | Open push menu |
| `<leader>gl` | Normal | `:Neogit log<CR>` | View Git log |
| `<leader>gb` | Normal | `toggle_blame` | Toggle inline Git blame for current line |

#### Neogit Workflow

1. **Open status**: Press `<leader>gs` to see all changes
2. **Stage changes**: 
   - Press `s` on a file to stage entire file
   - Press `s` on a hunk to stage individual hunk
   - Press `u` to unstage
3. **Commit**:
   - Press `c` then `c` to open commit buffer
   - Write commit message
   - Save (`:w`) and close (`:q`) to finalize
4. **Push**: Press `p` then `p` to push changes
5. **Help**: Press `?` in any view to see all commands

---

### Utilities

| Keybinding | Mode | Action | Description |
|------------|------|--------|--------------|
| `<leader>u` | Normal | Toggle UndoTree | Open visual undo history tree |

---

### Commenting (comment.nvim)

These are provided by the comment plugin:

| Keybinding | Mode | Action | Description |
|------------|------|--------|--------------|
| `gcc` | Normal | Toggle comment | Comment/uncomment current line |
| `gc` + motion | Normal | Toggle comment | Comment/uncomment with motion (e.g., `gcip` for paragraph) |
| `gbc` | Normal | Toggle block comment | Block comment current line |
| `gb` + motion | Normal | Toggle block comment | Block comment with motion |
| `gc` | Visual | Toggle comment | Comment/uncomment selected lines |
| `gb` | Visual | Toggle block comment | Block comment selected region |

---

## Visual Indicators

### Indent Guides

- **Dim gray lines** (`#3b4261`): Show all indent levels (barely visible)
- **TokyoNight blue** (`#7aa2f7`): Highlights the scope you're currently in (Treesitter-based)
- **Purple line** (`#bb9af7`): Highlights the exact indent level of your cursor (mini.indentscope)

### Foldcolumn

The left column shows fold levels with numbers:
- Numbers indicate nesting depth
- Click on numbers to fold/unfold that level
- Set to `vim.o.foldcolumn = '0'` to hide

### Rainbow Delimiters

Brackets, parentheses, and braces are colored by nesting level for easier matching.

---

## Automatic Features

### Format on Save

Files are automatically formatted when saved based on file type:
- **Nix**: alejandra
- **Lua**: stylua
- **Python**: black
- **JavaScript/TypeScript**: prettier
- **JSON/YAML/Markdown/HTML/CSS**: prettier
- **Bash/Shell**: shfmt

Fallback: LSP formatting if no formatter is configured.

### Git Blame

Inline Git blame is enabled by default:
- Shows author and date at end of line
- 500ms delay before appearing
- Toggle with `<leader>gb`

### Cursor Line

Current line is highlighted for easy cursor location.

### Relative Line Numbers

Line numbers are relative to cursor position for easier motion commands (e.g., `5j` to move down 5 lines).

---

## Configuration Location

NixOS configuration: `~/nixos/modules/utils/neovim.nix`

To apply changes:
```bash
cd ~/nixos
sudo nixos-rebuild switch --flake .
```

---

## Tips and Tricks

### Finding Files Quickly
1. `<leader>ff` - Start typing filename
2. Use fuzzy matching (e.g., "nvmcfg" matches "neovim-config")

### Code Navigation
1. Use `gd` to jump to definition
2. Use `<C-o>` to jump back
3. Use `K` to see documentation without leaving your code

### Multi-line Editing
1. Visual block mode: `<C-v>`
2. Select lines with `j/k`
3. `I` to insert at start, `A` to append at end
4. Type your text, then `<Esc>` to apply to all lines

### Working with Folds
1. Navigate to a function/block
2. `za` to collapse it
3. Move to other code
4. `za` again to expand when you return
5. Use `zM` to collapse everything for a high-level overview

### Searching in Files
1. `<leader>fg` to open live grep
2. Type your search term
3. Results update in real-time
4. Navigate with `<C-j>/<C-k>`, Enter to open

### Git Workflow with Neogit
1. Make changes to your files
2. `<leader>gs` to open status
3. Stage hunks with `s`, unstage with `u`
4. `c c` to commit, write message, save and quit
5. `p p` to push to remote

---

## Troubleshooting

### LSP Not Working
- Ensure language server is installed (check `extraPackages` in config)
- Restart Neovim: `:qa` then reopen
- Check LSP status: `:LspInfo`

### Formatting Not Working
- Verify formatter is in `extraPackages`
- Check `:ConformInfo` for formatter status
- Ensure file type is in `formatters_by_ft`

### Completion Not Showing
- Ensure LSP is attached: `:LspInfo`
- Try manual trigger: `<C-Space>` in insert mode
- Check if sources are loaded: `:lua =vim.inspect(require('cmp').get_config().sources)`

---

## Extending Configuration

### Adding a New Language Server

1. Add to `extraPackages`:
```nix
extraPackages = with pkgs; [
  # ... existing packages
  your-language-server
];
```

2. Configure in LSP section:
```lua
vim.lsp.config.your_ls = {
  cmd = { "your-language-server" },
  filetypes = { "yourfiletype" },
}
vim.lsp.enable('your_ls')
```

### Adding a New Formatter

1. Add to `extraPackages`
2. Add to `formatters_by_ft` in conform setup:
```lua
formatters_by_ft = {
  yourfiletype = { "your-formatter" },
}
```

### Adding a New Keybinding

Add to `extraLuaConfig`:
```lua
vim.keymap.set('n', '<leader>x', ':YourCommand<CR>', { desc = "Description" })
```

---

*Last updated: 2026-01-02*
