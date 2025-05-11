-- https://github.com/MeanderingProgrammer/render-markdown.nvim

--[[
- use character map from menu>accessories, select ubuntu mono nerd font & script=common -> pick an icon
- use :digraphs, select a character­℗  🯄and pick a character.
]]
return {

  'MeanderingProgrammer/render-markdown.nvim',

  enabled = true,

  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'echasnovski/mini.icons',
  },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    render_modes = { 'n', 'c', 't' },
    checkbox = {
      enabled = true,
      render_modes = { 'n', 'c', 't' },
      right_pad = 1,
      unchecked = { icon = '󰄱 ', highlight = 'RenderMarkdownUnchecked', scope_highlight = nil },
      checked = { icon = '󰱒 ', highlight = 'RenderMarkdownChecked', scope_highlight = nil },
      custom = {
        ongoing = {
          raw = '[o]',
          rendered = '󰥔 ',
          highlight = 'RenderMarkdownTodo',
          scope_highlight = '@markup.italic',
        },
        cancel = { raw = '[c]', rendered = '⮾  ', highlight = 'ErrorMsg', scope_highlight = '@markup.strikethrough' },
        -- override render-markdown's existing custom 'todo'
        todo = { raw = '[-]', rendered = '⮾  ', highlight = 'ErrorMsg', scope_highlight = '@markup.strikethrough' },
        important = { raw = '[!]', rendered = '󰓎 ', highlight = 'DiagnosticWarn' },
        maybe = { raw = '[?]', rendered = '�  ', highlight = 'RenderMarkdownTodo' },
      },
      -- % charmap -> choose Nerd Font Mono -> copy/paste characters
      -- cancel icons: ✝ ♰ ♽ ⨷ ⮾ 𝛩 𝛳 𝜃 🄯 🄫 🅒 🜔 ⛔ 🚫 ⚠️ ♻️ 📛 ⏲a  🕓
      -- 🯄, �  ⍰
    },
  },

  keys = {
    { '<leader>r', '<cmd>RenderMarkdown toggle<cr>', mode = 'n', desc = 'Toggle RenderMarkdown' },
  },
}
