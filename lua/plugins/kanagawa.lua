-- https://github.com/rebelot/kanagawa.nvim
--  If you enabled compile in the config, then after each config change:
--  1. modify your config
--  2. restart nvim
--  3. :KanagawaCompile

return {
  {

    'rebelot/kanagawa.nvim',

    lazy = false, -- load this color scheme during startup
    priority = 1000, -- load before all other plugins

    config = function()
      -- runs when plugin is loaded (don't use opts = {..} in this spec, that'll be ignored)
      local opts = {
        transparent = true,
        overrides = function(_)
          return {
            -- https://github.com/rebelot/kanagawa.nvim/issues/207
            ['@markup.link.url.markdown_inline'] = { link = 'Special' }, -- (url)
            ['@markup.link.label.markdown_inline'] = { link = 'WarningMsg' }, -- [label]
            ['@markup.link.markdown_inline'] = { link = 'WarningMsg' }, -- [label]
            ['@markup.italic.markdown_inline'] = { link = 'Exception' }, -- *italic*
            ['@markup.raw.markdown_inline'] = { link = 'String' }, -- `code`
            ['@markup.list.markdown'] = { link = 'Function' }, -- + list
            ['@markup.quote.markdown'] = { link = 'Error' }, -- > blockcode
            ['@comment.todo.comment'] = { link = 'Cursor' },
            ['@comment.note.comment'] = { link = 'Cursor' },
            ['@markup.list.checked.markdown'] = { link = 'WarningMsg' },
          }
        end,
        colors = {
          theme = {
            all = {
              ui = { bg_gutter = 'none' },
            },
          },
        },
      }
      require('kanagawa').setup(opts)
      vim.cmd [[colorscheme kanagawa]]
    end,
  },
}
