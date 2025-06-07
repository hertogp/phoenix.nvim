-- https://github.com/folke/snacks.nvim/tree/main

return {
  'folke/snacks.nvim',

  priority = 1000,
  lazy = false,

  ---@type snacks.Config
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
    bigfile = { enabled = true },
    dashboard = { enabled = false },
    explorer = { enabled = true },
    indent = { enabled = true },
    input = { enabled = true },
    picker = {
      enabled = true,

      -- makes all pickers start in normal mode!
      -- on_show = function()
      --   vim.cmd.stopinsert()
      -- end,
    },
    notifier = { enabled = true },
    quickfile = { enabled = true },
    scope = { enabled = true },
    scroll = { enabled = true },
    statuscolumn = { enabled = true },
    words = { enabled = true },
  },
  layout = {
    cycle = false, -- do not wrap around
  },
  keys = {
    -- `:!open https://github.com/folke/snacks.nvim/blob/main/README.md#-usage`

    -- Top Pickers & Explorer
    {
      '<space>,',
      function()
        Snacks.picker.smart()
      end,
      desc = 'Smart Find Files',
    },
    {
      '<space>b',
      function()
        Snacks.picker.buffers({
          hidden = true,
          nofile = false,
          prompt = ' > ',
          on_show = function()
            vim.cmd.stopinsert()
          end,
          win = {
            list = {
              keys = {
                ['dd'] = 'bufdelete',
              },
            },
          },
        })
      end,
      desc = 'Buffers',
    },

    -- diagnostics
    {
      '<space>d',
      function()
        -- works when on a line with an error or warning, quick inspection
        vim.diagnostic.open_float()
      end,
      desc = 'diagnostic, open float',
    },
    {
      '<space>D',
      function()
        Snacks.picker.diagnostics_buffer()
      end,
      desc = 'Diagnostics',
    },
    {
      '<space>N',
      function()
        Snacks.picker.notifications({
          on_show = function()
            vim.cmd.stopinsert()
          end,
        })
      end,
      desc = 'Notifications',
    },
    {
      '<space>f',
      function()
        Snacks.picker.files()
      end,
      desc = 'Find Files',
    },
    {
      '<space>F',
      function()
        Snacks.picker.files({ cwd = vim.fn.expand('%:p:h') })
      end,
      desc = 'Find Bufdir',
    },
    {
      '<space>l',
      function()
        Snacks.picker.lines({
          -- search for 'cWORD under cursor (' means literal match for cWORD)
          pattern = "'" .. (vim.fn.expand('<cWORD>'):match('[%w_%.:]+') or ''),
          prompt = ' > ',
          on_show = function()
            vim.cmd.stopinsert()
          end,
          layout = {
            relative = 'editor',
          },
        })
      end,
      desc = 'Buffer Lines for cWORD',
    },
    {
      '<space>L',
      function()
        Snacks.picker.lines()
      end,
      desc = 'Buffer Lines',
    },
    {
      '<space>g',
      function()
        Snacks.picker.grep({
          prompt = ' > ',
          on_show = function()
            vim.cmd.stopinsert()
          end,
          search = function(_)
            return vim.fn.expand('<cWORD>'):match('[%w_%.:]+') or ''
          end,
        })
      end,
      desc = 'Grep',
    },
    {
      '<space>G',
      function()
        Snacks.picker.grep()
      end,
      desc = 'Grep',
    },
    {
      '<space>n',
      function()
        Snacks.picker.notifications({
          prompt = ' > ',
          on_show = function()
            vim.cmd.stopinsert()
          end,
        })
      end,
      desc = 'Notification History',
    },
    {
      '<space>e',
      function()
        Snacks.explorer()
      end,
      desc = 'File Explorer',
    },
    {
      '<space>h',
      function()
        Snacks.picker.help({
          win = {
            input = {
              keys = {
                ['<CR>'] = { 'tab', mode = { 'n', 'i' } },
              },
            },
          },
        })
      end,
      desc = 'Help',
    },
    {
      '<space>H',
      function()
        Snacks.picker.help({
          pattern = vim.fn.expand('<cWORD>'):match('[%w_%.:]+') or '',
          win = {
            input = {
              keys = {
                ['<CR>'] = { 'tab', mode = { 'n', 'i' } },
              },
            },
          },
        })
      end,
      desc = 'Help on <cword>',
    },
    {
      '<space>s',
      function()
        Snacks.picker.lsp_symbols()
      end,
      desc = 'LSP: Find symbol',
    },
    {
      '<space>S',
      function()
        Snacks.picker.lsp_workspace_symbols()
      end,
      desc = 'LSP: Find workspace symbol',
    },
    {
      '<space>k',
      function()
        Snacks.picker.keymaps()
      end,
      desc = 'Find keymap',
    },
    {
      '<space>m',
      function()
        Snacks.picker.man()
      end,
      desc = 'Find Manpages',
    },

    -- pdh/outline.lua
    {
      '<space>o',
      function()
        require 'pdh.outline'.toggle()
      end,
      desc = 'Toggle Outline of file',
    },
    {
      '<space><space>',
      function()
        Snacks.picker.resume()
      end,
      desc = '[r]esume last search',
    },

    {
      '<space>w',
      function()
        Snacks.picker.grep_word()
      end,
      desc = 'Grep word',
    },

    --[[ find & find ]]

    -- stdpath config
    {
      '<leader>fc',
      function()
        Snacks.picker.files({ cwd = vim.fn.stdpath('config') })
      end,
      desc = 'Find Config',
    },
    {
      '<leader>gc',
      function()
        Snacks.picker.grep({ cwd = vim.fn.stdpath('config') })
      end,
      desc = 'Grep Config',
    },

    -- stdpath data
    {
      '<leader>fd',
      function()
        Snacks.picker.files({ cwd = vim.fn.stdpath('data') })
      end,
      desc = 'Find Data',
    },
    {
      '<leader>gd',
      function()
        Snacks.picker.grep({ cwd = vim.fn.stdpath('data') })
      end,
      desc = 'Grep Data',
    },

    -- qf & winloc
    {
      '<leader>q',
      function()
        Snacks.picker.qflist()
      end,
      desc = 'Quickfix list',
    },
    {
      '<leader>w',
      function()
        Snacks.picker.loclist()
      end,
      desc = 'Window loclist',
    },

    -- notes
    {
      '<leader>fn',
      function()
        Snacks.picker.files({ cwd = '~/notes/' })
      end,
      desc = 'Find Notes',
    },
    {
      '<leader>gn',
      function()
        Snacks.picker.grep({ cwd = '~/notes/' })
      end,
      desc = 'Grep Notes',
    },

    -- project dir
    {
      '<leader>fp',
      function()
        Snacks.picker.files({ cwd = Project_root() })
      end,
      desc = 'Find Project',
    },
    {
      '<leader>gp',
      function()
        Snacks.picker.grep({ cwd = Project_root() })
      end,
      desc = 'Grep Project',
    },

    -- todo's
    {
      '<leader>ft',
      function()
        Snacks.picker.grep({
          buf = true,
          cwd = vim.fn.expand('%:p:h'),
          search = 'TODO|ToDo|FIXME|NOTES?|BUG|XXX|REVIEW',
        })
      end,
      desc = 'Find Todo-s',
    },
    {
      '<leader>gt',
      function()
        Snacks.picker.grep({ cwd = Project_root(), search = 'TODO|ToDo|FIXME|NOTES?|BUG|XXX|REVIEW' })
      end,
      desc = 'Find Project Todo-s',
    },

    -- git
    {
      '<leader>fg',
      function()
        Snacks.picker.git_files()
      end,
      desc = 'Find Git Files',
    },

    -- Misc
    {
      '<leader>c',
      function()
        Snacks.picker.commands()
      end,
      desc = 'Find Command',
    },

    {
      '<leader>i',
      function()
        Snacks.picker.icons()
      end,
      desc = 'Find Icon',
    },

    {
      '<leader>p',
      function()
        Snacks.picker.pickers()
      end,
      desc = 'Find Command',
    },

    {
      '<leader>H',
      function()
        Snacks.picker.highlights()
      end,
      desc = 'Find Command',
    },

    -- LSP
    {
      'gd',
      function()
        Snacks.picker.lsp_definitions()
      end,
      desc = 'LSP: Goto Definition',
    },
    {
      'gD',
      function()
        Snacks.picker.lsp_declarations()
      end,
      desc = 'LSP: Goto Declaration',
    },
    {
      'gr',
      function()
        Snacks.picker.lsp_references()
      end,
      nowait = true,
      desc = 'LSP: References',
    },
    {
      'gi',
      function()
        Snacks.picker.lsp_implementations()
      end,
      desc = 'LSP: Goto Implementation',
    },
    {
      'gy',
      function()
        Snacks.picker.lsp_type_definitions()
      end,
      desc = 'LSP: Goto T[y]pe Definition',
    },
    -- {
    --   '<leader>ss',
    --   function()
    --     Snacks.picker.lsp_symbols()
    --   end,
    --   desc = 'LSP Symbols',
    -- },
    -- {
    --   '<leader>sS',
    --   function()
    --     Snacks.picker.lsp_workspace_symbols()
    --   end,
    --   desc = 'LSP Workspace Symbols',
    -- },
  },
}
