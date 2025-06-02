-- https://github.com/ibhagwan/fzf-lua
-- https://github.com/ibhagwan/fzf-lua/wiki
-- https://github.com/ibhagwan/fzf-lua/wiki/Advanced
-- https://github.com/ibhagwan/fzf-lua/wiki/Options (provider options for commands)

return {
  'ibhagwan/fzf-lua',
  -- optional for icon support
  dependencies = { 'echasnovski/mini.icons' },
  opts = {
    -- see 'defaults.lua' for available (default) actions
    helptags = {
      actions = {
        ['enter'] = {
          fn = function(selected, opts)
            require 'fzf-lua'.actions.help_tab(selected, opts)
          end,
        },
      },
    },
    manpages = {
      actions = {
        ['enter'] = {
          fn = function(selected, opts)
            require 'fzf-lua'.actions.man_tab(selected, opts)
          end,
        },
      },
    },
  },
  keys = {
    -- buffers, files
    -- TODO:
    -- [ ] <space>f{n, f, F, p, P} to find:
    --     n = notes
    --     N = grep notes
    --     f = files under current project (if any)
    --     F = files under current buffer directory
    --     p = files under my nvim setup
    --     P = files under nvim's data path (stdpath('data')/nvim)
    --     N = neovim files under stdpath('cache')
    --     n = neovim files under stdpath('data')
    -- [ ] <space>g{n,f,F,p,P,n,N} - same as <space>f<*> but grep instead of find

    -- { '<space>b', ":lua require 'fzf-lua'.buffers()<cr>", desc = '[b]uffers' },

    -- find & grep
    -- {
    --   '<space>ff',
    --   ":lua require 'fzf-lua'.files({hidden=true, cwd=Project_root()})<cr>",
    --   desc = 'find, project dir',
    -- },
    -- {
    --   '<space>gf',
    --   ":lua require 'fzf-lua'.live_grep({hidden=true, cwd=Project_root()})<cr>",
    --   desc = 'grep, project dir',
    -- },
    -- {
    --   '<space>fF',
    --   ":lua require 'fzf-lua'.files({hidden=true, cwd=vim.fn.expand('%:p:h')})<cr>",
    --   desc = 'find, buffer dir',
    -- },
    -- {
    --   '<space>gF',
    --   ":lua require 'fzf-lua'.live_grep({hidden=true, cwd=vim.fn.expand('%:p:h')})<cr>",
    --   desc = 'grep, buffer dir',
    -- },
    -- {
    --   '<space>fn',
    --   ":lua require 'fzf-lua'.files({cwd='~/notes', query='md$ | txt$ '})<cr>",
    --   desc = 'find, notes',
    -- },
    -- use '<term> -- *.md *.txt !z.*' to grep only in md or txt files and never in z.ext files
    -- {
    --   '<space>gn',
    --   ":lua require 'fzf-lua'.live_grep({cwd='~/notes'})<cr>",
    --   desc = 'grep, notes',
    -- },
    -- {
    --   '<space>fc',
    --   ":lua require 'fzf-lua'.files({hidden=true, cwd=vim.fn.stdpath('config')})<cr>",
    --   desc = 'find, stdpath(config)',
    -- },
    -- {
    --   '<space>gc',
    --   ":lua require 'fzf-lua'.live_grep({hidden=true, cwd=vim.fn.stdpath('config')})<cr>",
    --   desc = 'grep, stdpath(config)',
    -- },
    -- {
    --   '<space>fd',
    --   ":lua require 'fzf-lua'.files({hidden=true, cwd=vim.fn.stdpath('data')})<cr>",
    --   desc = 'find, stdpath(data)',
    -- },
    -- {
    --   '<space>gd',
    --   ":lua require 'fzf-lua'.live_grep({hidden=true, cwd=vim.fn.stdpath('data')})<cr>",
    --   desc = 'grep, stdpath(data)',
    -- },
    -- {
    --   '<space>ft',
    --   ":lua require 'fzf-lua'.grep_curbuf({no_esc=true, search='TODO: | XXX: | FIXME: | REVIEW: | NOTES?: | BUG: '})<cr>",
    --   desc = "find, buffer todo's",
    -- },
    -- {
    --   '<space>fT',
    --   ":lua require 'fzf-lua'.live_grep({no_esc=true, hidden=true, cwd=Project_root(), search='TODO: | XXX: | FIXME: | REVIEW: | NOTES?: | BUG: '})<cr>",
    --   desc = "find, project todo's",
    -- },

    -- muscle memory fades slowly it seems
    -- { '<space>l', ":lua require 'fzf-lua'.blines()<cr>", desc = 'grep, buffer' },
    -- { '<space>fl', ":lua require 'fzf-lua'.blines()<cr>", desc = 'grep, buffer' },
    -- greps buffer's file (last save) on disk (won't work on nofile buffers)
    -- { '<space>gl', ":lua require 'fzf-lua'.grep_curbuf()<cr>", desc = 'grep, saved buffer' },

    -- help
    -- {
    --   '<space>H',
    --   ":lua require 'fzf-lua'.helptags({query = vim.fn.expand('<cword>')})<cr>",
    --   desc = 'find, neovim help <cword>',
    -- },
    -- {
    --   '<space>h',
    --   ":lua require 'fzf-lua'.helptags()<cr>",
    --   desc = 'find, neovim helptags',
    -- },

    -- diagnostics
    -- {
    --   '<space>d',
    --   ':lua vim.diagnostic.open_float()<cr>',
    --   -- vim.diagnostic.enable(not vim.diagnostic.is_enabled())
    --   desc = 'diagnostic, open float',
    -- },
    -- {
    --   '<space>D',
    --   ":lua require 'fzf-lua'.diagnostics_document()<cr>",
    --   desc = 'find, doc diagnostics',
    -- },
    -- {
    --   '<space>s',
    --   ":lua require 'fzf-lua'.lsp_document_symbols()<cr>",
    --   desc = 'document [s]ymbols',
    -- },

    -- misc
    -- { '<space>q', ':FzfLua quickfix<cr>', desc = 'quickfix' },
    -- { '<space>w', ':FzfLua loclist<cr>', desc = 'window loclist' },

    { '<space>B', ":lua require 'fzf-lua'.builtin()<cr>", desc = 'find, builtin commands' },
    -- { '<space>k', ":lua require 'fzf-lua'.keymaps()<cr>", desc = 'find, key mappings' },
    -- { '<space>m', ":lua require 'fzf-lua'.man_pages()<cr>", desc = 'find, man pages' },

    -- { '<leader>w', ":lua require 'fzf-lua'.grep_cword()<cr>", desc = 'find current word' },
    -- { '<leader>W', ":lua require 'fzf-lua'.grep_cWORD()<cr>", desc = 'find current WORD' },

    { '<space>O', ":lua require 'fzf-lua'.nvim_options()<cr>", desc = 'vim [O]ptions' },
    -- { '<space><space>', ":lua require 'fzf-lua'.resume()<cr>", desc = '[r]esume last search' },
    -- { '<space>o', ":lua require 'pdh.outline'.toggle()<cr>", desc = 'Toggle Outline of file' },
  },
  lsp = {
    code_actions = {
      previewer = 'codeaction_native',
      preview_pager = 'delta --side-by-side --width=$FZF_PREVIEW_COLUMNS',
    },
  },
}
