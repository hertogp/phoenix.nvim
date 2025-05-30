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
    { '<space>b', ":lua require 'fzf-lua'.buffers()<cr>", desc = '[b]uffers' },
    {
      '<space>ff',
      ":lua require 'fzf-lua'.files({hidden=true, cwd=Project_root()})<cr>",
      desc = 'find [f]iles in cur project',
    },
    {
      '<space>fF',
      ":lua require 'fzf-lua'.files({hidden=true, cwd=vim.fn.expand('%:p:h')})<cr>",
      desc = 'find [F]iles in cur bufdir',
    },
    {
      '<space>fn',
      ":lua require 'fzf-lua'.files({cwd='~/notes', query='.md$ '})<cr>",
      desc = 'find in [n]otes dirs',
    },
    -- use '<term> -- *.md *.txt !z.*' to grep only in md or txt files and never in z.ext files
    {
      '<space>fN',
      ":lua require 'fzf-lua'.live_grep({cwd='~/notes'})<cr>",
      desc = 'find in [N]otes grep',
    },
    {
      '<space>fp',
      ":lua require 'fzf-lua'.files({hidden=true, cwd=vim.fn.stdpath('config')})<cr>",
      desc = 'find [p]lugin stdpath(config) files',
    },
    {
      '<space>fP',
      ":lua require 'fzf-lua'.files({hidden=true, cwd=vim.fn.stdpath('data')})<cr>",
      desc = 'find [P]lugin stdpath(data) files',
    },
    {
      '<space>g',
      ":lua require 'fzf-lua'.live_grep({hidden=true, cwd=Project_root()})<cr>",
      desc = '[g]rep project directory',
    },
    { '<space>l', ":lua require 'fzf-lua'.blines()<cr>", desc = '[l]ines in buffer' },
    -- greps buffer's file (last save) on disk (won't work on nofile buffers)
    { '<space>L', ":lua require 'fzf-lua'.grep_curbuf()<cr>", desc = '[l]ines in buffer (fuzzy)' },
    { '<space>q', ':FzfLua quickfix<cr>', desc = '[q]uickfix' },
    { '<space>w', ':FzfLua loclist<cr>', desc = '[w]indow location list' },
    -- keep typing to narrow down
    {
      '<space>t',
      ":lua require 'fzf-lua'.grep_curbuf({no_esc=true, search='TODO: | XXX: | FIXME: | REVIEW: | NOTES?: | BUG: '})<cr>",
      desc = "[t]odo's and friends in buffer",
    },
    {
      '<space>T',
      ":lua require 'fzf-lua'.live_grep({no_esc=true, hidden=true, cwd=Project_root(), search='TODO: | XXX: | FIXME: | REVIEW: | NOTES?: | BUG: '})<cr>",
      desc = "[t]odo's and friends in project",
    },

    -- help
    {
      '<space>H',
      ":lua require 'fzf-lua'.helptags({query = vim.fn.expand('<cword>')})<cr>",
      desc = 'find neovim [h]elp for cword',
    },
    {
      '<space>h',
      ":lua require 'fzf-lua'.helptags()<cr>",
      desc = 'find neovm [h]elp via helptags',
    },
    { '<space>B', ":lua require 'fzf-lua'.builtin()<cr>", desc = 'find fzf [b]uiltin commands' },
    { '<space>k', ":lua require 'fzf-lua'.keymaps()<cr>", desc = 'find [k]ey mappings' },
    { '<space>M', ":lua require 'fzf-lua'.man_pages()<cr>", desc = 'find [M]an pages' },
    {
      '<space>D',
      ":lua require 'fzf-lua'.diagnostics_document()<cr>",
      desc = 'find diagnostics of document',
    },
    {
      '<space>d',
      ':lua vim.diagnostic.open_float()<cr>',
      -- vim.diagnostic.enable(not vim.diagnostic.is_enabled())
      desc = 'toggle Diasnostics',
    },
    { '<leader>D', ':lua vim.diagnostic.enable(not vim.diagnostic.is_enabled())<cr>', desc = 'toggle diagnostics' },

    -- grep
    { '<leader>w', ":lua require 'fzf-lua'.grep_cword()<cr>", desc = 'find current word' },
    { '<leader>W', ":lua require 'fzf-lua'.grep_cWORD()<cr>", desc = 'find current WORD' },
    { '<space>O', ":lua require 'fzf-lua'.nvim_options()<cr>", desc = 'vim [O]ptions' },

    -- misc
    { '<space><space>', ":lua require 'fzf-lua'.resume()<cr>", desc = '[r]esume last search' },
    {
      '<space>s',
      ":lua require 'fzf-lua'.lsp_document_symbols()<cr>",
      desc = 'document [s]ymbols',
    },
    { '<space>o', ":lua require 'pdh.outline'.toggle()<cr>", desc = 'Toggle Outline of file' },
  },
  lsp = {
    code_actions = {
      previewer = 'codeaction_native',
      preview_pager = 'delta --side-by-side --width=$FZF_PREVIEW_COLUMNS',
    },
  },
}
