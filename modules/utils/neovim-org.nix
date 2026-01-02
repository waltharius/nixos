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
          -- ========================================
          -- ORG-MODE CONFIGURATION
          -- ========================================
          require('orgmode').setup({
            org_agenda_files = '~/notes/**/*',
            org_default_notes_file = '~/notes/inbox.org',

            -- Preserve Emacs-style TODO keywords
            org_todo_keywords = {'TODO', 'IN-PROGRESS', 'WAITING', '|', 'DONE', 'CANCELED'},

            -- Calendar week starts on Monday (European style)
            calendar_week_start_day = 1,

            -- Preserve original org file format (no auto-formatting)
            org_startup_folded = 'showeverything',
            org_indent_mode = 'noindent',

            -- Org-capture templates (will be extended with custom functions)
            org_capture_templates = {
              t = {
                description = 'Task',
                template = '* TODO %?\n  SCHEDULED: %t',
                target = '~/notes/inbox.org'
              },
            },

            -- Disable agenda (not used much)
            org_agenda_skip_scheduled_if_done = true,
            org_agenda_skip_deadline_if_done = true,
          })

          -- ========================================
          -- DENOTE-STYLE FILE NAMING
          -- ========================================

          local notes_dir = vim.fn.expand('~/notes/')

          -- Generate denote filename: YYYYMMDDTHHMMSS--title__tags.org
          local function denote_filename(title, tags, signature)
            local timestamp = os.date('%%Y%%m%%dT%%H%%M%%S')
            local slug_title = title:lower():gsub('[^%%w]+', '-'):gsub('^-+', ''''):gsub('-+$', '''')
            local tags_str = ''''

            if tags and #tags > 0 then
              tags_str = '__' .. table.concat(tags, '_')
            end

            local sig_str = ''''
            if signature and signature ~= '''' then
              sig_str = '==' .. signature
            end

            return string.format('%%s--%%s%%s%%s.org', timestamp, slug_title, tags_str, sig_str)
          end

          -- ========================================
          -- JOURNAL WORKFLOW (C-n j / C-n J)
          -- ========================================

          -- Get today's date in YYYYMMDD format
          local function get_date_string(date_override)
            if date_override then
              return date_override
            end
            return os.date('%%Y%%m%%d')
          end

          -- Find existing journal file for a date
          local function find_journal_file(date_str)
            local pattern = date_str .. 'T.*%-%-.*journal__.*\\.org$'
            local handle = io.popen('find ' .. notes_dir .. ' -maxdepth 1 -name "' .. date_str .. 'T*journal*.org" 2>/dev/null')
            if handle then
              local result = handle:read('*a')
              handle:close()
              if result and result ~= '''' then
                return result:gsub('%%s+$', '''')
              end
            end
            return nil
          end

          -- Create journal template with proper format
          local function create_journal_template(date_str, time_str)
            local date_obj = {
              year = date_str:sub(1, 4),
              month = date_str:sub(5, 6),
              day = date_str:sub(7, 8)
            }

            local formatted_date = string.format('%%s-%%s-%%s', date_obj.year, date_obj.month, date_obj.day)
            local weekday = os.date('%%A', os.time({
              year = tonumber(date_obj.year),
              month = tonumber(date_obj.month),
              day = tonumber(date_obj.day)
            }))

            local template = {
              '#+TITLE: ' .. formatted_date .. ' Journal',
              '#+DATE: [' .. formatted_date .. ' ' .. weekday .. ']',
              '#+FILETAGS: :journal:',
              "",
              '* ' .. time_str .. ' Entry',
              "",
              '** Wellbeing',
              'Mood: ',
              'Energy: ',
              'Focus: ',
              "",
              '** Notes',
              "",
            }

            return template
          end

          -- Add new time entry to existing journal
          local function add_journal_entry(filepath)
            local time_str = os.date('%%H:%%M')
            local entry = {
              "",
              '* ' .. time_str .. ' Entry',
              "",
              '** Notes',
              "",
            }

            -- Open file and append
            vim.cmd('edit ' .. filepath)
            local line_count = vim.api.nvim_buf_line_count(0)
            vim.api.nvim_buf_set_lines(0, line_count, line_count, false, entry)

            -- Jump to new entry
            vim.api.nvim_win_set_cursor(0, {line_count + 5, 0})
          end

          -- Main journal function (C-n j)
          function Journal_today()
            local date_str = get_date_string()
            local existing = find_journal_file(date_str)

            if existing then
              add_journal_entry(existing)
              print('Added new entry to today journal')
            else
              -- Create new journal file
              local timestamp = os.date('%%Y%%m%%dT%%H%%M%%S')
              local filename = timestamp .. '--' .. date_str .. '-journal__journal.org'
              local filepath = notes_dir .. filename

              local time_str = os.date('%%H:%%M')
              local template = create_journal_template(date_str, time_str)

              -- Write file
              local file = io.open(filepath, 'w')
              if file then
                file:write(table.concat(template, '\n'))
                file:close()
                vim.cmd('edit ' .. filepath)
                print('Created new journal: ' .. filename)
              else
                print('Error creating journal file')
              end
            end
          end

          -- Journal for past date (C-n J)
          function Journal_past_date()
            -- Prompt for date
            vim.ui.input({
              prompt = 'Journal date (YYYY-MM-DD): ',
              default = os.date('%%Y-%%m-%%d')
            }, function(input)
              if not input or input == '''' then
                print('Canceled')
                return
              end

              -- Parse date
              local year, month, day = input:match('(%%d%%d%%d%%d)%-(%%d%%d)%-(%%d%%d)')
              if not year then
                print('Invalid date format. Use YYYY-MM-DD')
                return
              end

              local date_str = year .. month .. day
              local existing = find_journal_file(date_str)

              if existing then
                vim.cmd('edit ' .. existing)
                print('Opened existing journal for ' .. input)
              else
                -- Create past date journal with T000000
                local timestamp = date_str .. 'T000000'
                local filename = timestamp .. '--' .. date_str .. '-journal__journal.org'
                local filepath = notes_dir .. filename

                local template = create_journal_template(date_str, '00:00')

                local file = io.open(filepath, 'w')
                if file then
                  file:write(table.concat(template, '\n'))
                  file:close()
                  vim.cmd('edit ' .. filepath)
                  print('Created journal for ' .. input)
                else
                  print('Error creating journal file')
                end
              end
            end)
          end

          -- ========================================
          -- GENERAL NOTE CREATION (C-n n)
          -- ========================================

          function Create_note()
            vim.ui.input({ prompt = 'Note title: ' }, function(title)
              if not title or title == '''' then
                print('Canceled')
                return
              end

              vim.ui.input({ prompt = 'Tags (space-separated): ' }, function(tags_input)
                local tags = {}
                if tags_input and tags_input ~= '''' then
                  for tag in tags_input:gmatch('%%S+') do
                    table.insert(tags, tag)
                  end
                end

                local filename = denote_filename(title, tags, nil)
                local filepath = notes_dir .. filename

                local template = {
                  '#+TITLE: ' .. title,
                  '#+DATE: [' .. os.date('%%Y-%%m-%%d %%A') .. ']',
                  '#+FILETAGS: :' .. table.concat(tags, ':') .. ':',
                  "",
                  '* Notes',
                  "",
                }

                local file = io.open(filepath, 'w')
                if file then
                  file:write(table.concat(template, '\n'))
                  file:close()
                  vim.cmd('edit ' .. filepath)
                  print('Created: ' .. filename)
                else
                  print('Error creating note')
                end
              end)
            end)
          end

          -- ========================================
          -- KEYBINDINGS (C-n = <leader>n)
          -- ========================================

          vim.keymap.set('n', '<leader>nj', Journal_today, { desc = 'Journal today (or add entry)' })
          vim.keymap.set('n', '<leader>nJ', Journal_past_date, { desc = 'Journal past date' })
          vim.keymap.set('n', '<leader>nn', Create_note, { desc = 'Create new note' })

          -- Org-mode specific keybindings
          vim.keymap.set('n', '<leader>na', '<cmd>lua require("orgmode").action("agenda.prompt")<CR>', { desc = 'Org agenda' })
          vim.keymap.set('n', '<leader>nc', '<cmd>lua require("orgmode").action("capture.prompt")<CR>', { desc = 'Org capture' })

          print('Org-mode module loaded! Use <leader>nj for journal, <leader>nn for notes')
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
