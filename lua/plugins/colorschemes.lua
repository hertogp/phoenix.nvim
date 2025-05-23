-- consistent CursorLine (a.o.) across colorschemes
vim.cmd [[
  augroup auColorScheme
   autocmd colorscheme * :highlight CursorLine guibg=#203040
   autocmd colorscheme * :highlight Normal guibg=None
   " autocmd colorscheme * :echomsg "change bgcolor fixed!"
  augroup END
]]

vim.api.nvim_set_hl(0, 'ColorColumn', { ctermbg = 'DarkGrey', ctermfg = 'white' })
-- vim.api.nvim_set_hl(0,"Pmenu",{ cterm = { italic = true }, ctermfg = "white", ctermbg = "darkgrey" })
-- vim.api.nvim_set_hl(0,"PmenuSel", { cterm = { italic = true }, ctermfg = "white", ctermbg = "darkblue" })
-- vim.api.nvim_set_hl(0, "LineNr", { ctermfg = 239, ctermbg = 234 })

return {

  -- { -- https://github.com/rebelot/kanagawa.nvim
  --   --  If you enabled compile in the config, then after each config change:
  --   --  1. modify your config
  --   --  2. restart nvim
  --   --  3. :KanagawaCompile
  --
  --   'rebelot/kanagawa.nvim',
  --
  --   lazy = false, -- load this color scheme during startup
  --   priority = 1000, -- load before all other plugins
  --
  --   config = function()
  --     -- runs when plugin is loaded (don't use opts = {..} in this spec, that'll be ignored)
  --     local opts = {
  --       transparent = true,
  --       overrides = function(_)
  --         return {
  --           -- https://github.com/rebelot/kanagawa.nvim/issues/207
  --           ['@markup.link.url.markdown_inline'] = { link = 'Special' }, -- (url)
  --           ['@markup.link.label.markdown_inline'] = { link = 'WarningMsg' }, -- [label]
  --           ['@markup.italic.markdown_inline'] = { link = 'Exception' }, -- *italic*
  --           ['@markup.raw.markdown_inline'] = { link = 'String' }, -- `code`
  --           ['@markup.list.markdown'] = { link = 'Function' }, -- + list
  --           ['@markup.quote.markdown'] = { link = 'Error' }, -- > blockcode
  --           ['@comment.todo.comment'] = { link = 'Cursor' },
  --           ['@comment.note.comment'] = { link = 'Cursor' },
  --           ['@markup.list.checked.markdown'] = { link = 'WarningMsg' },
  --         }
  --       end,
  --       colors = {
  --         theme = {
  --           all = {
  --             ui = { bg_gutter = 'none' },
  --           },
  --         },
  --       },
  --     }
  --     require('kanagawa').setup(opts)
  --     vim.cmd [[colorscheme kanagawa]]
  --   end,
  -- },

  { -- https://github.com/NAlexPear/Spacegray.nvim
    'NAlexPear/Spacegray.nvim',
    -- lazy = false, -- load this during startup
    -- priority = 1000, -- load before all other plugins
    -- config = function()
    --   -- runs when plugin is loaded (don't use opts = {..})
    --   vim.cmd [[colorscheme spacegray]]
    -- end,
  },

  { -- https://github.com/Mofiqul/dracula.nvim

    'Mofiqul/dracula.nvim',

    opts = {

      show_end_of_buffer = true, -- '~' characters after the end of buffers
      transparent_bg = true,
      lualine_bg_color = '#44475a',
      italic_comment = true,
      overrides = {}, -- override default highlights, see `:h synIDattr`

      colors = {
        bg = '#191A21',
        fg = '#F8F8F2',
        selection = '#44475A',
        comment = '#6272A4',
        red = '#FF5555',
        orange = '#FFB86C',
        yellow = '#F1FA8C',
        green = '#50fa7b',
        purple = '#BD93F9',
        cyan = '#8BE9FD',
        pink = '#FF79C6',
        bright_red = '#FF6E6E',
        bright_green = '#69FF94',
        bright_yellow = '#FFFFA5',
        bright_blue = '#D6ACFF',
        bright_magenta = '#FF92DF',
        bright_cyan = '#A4FFFF',
        bright_white = '#FFFFFF',
        menu = '#21222C',
        visual = '#3E4452',
        gutter_fg = '#4B5263',
        nontext = '#3B4048',
      },
    },
  },
}
