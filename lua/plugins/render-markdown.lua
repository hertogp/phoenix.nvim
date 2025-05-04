-- https://github.com/MeanderingProgrammer/render-markdown.nvim

--[[
- use character map from menu>accessories, select ubuntu mono nerd font & script=common -> pick an icon
]]
return {

  "MeanderingProgrammer/render-markdown.nvim",

  enabled = true,

  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "echasnovski/mini.icons",
    -- "nvim-tree/nvim-web-devicons",
  },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    render_modes = { "n", "c", "t" },
    checkbox = {
      enabled = true,
      render_modes = { "n", "c", "t" },
      right_pad = 1,
      unchecked = {
        icon = "󰄱 ",
        highlight = "RenderMarkdownUnchecked",
        scope_highlight = nil,
      },
      checked = {
        icon = "󰱒 ",
        highlight = "RenderMarkdownChecked",
        scope_highlight = nil,
      },
      custom = {
        todo = {
          raw = "[-]",
          rendered = "󰥔 ",
          highlight = "RenderMarkdownTodo",
          scope_highlight = nil,
        },
        cancel = {
          raw = "[c]",
          rendered = "🜔 ",
          highlight = "RenderMarkdownTodo",
          scope_highlight = "@markup.strikethrough",
        },
        important = { raw = "[!]", rendered = "󰓎 ", highlight = "DiagnosticWarn" },
      },
      -- cancel icons: ✝ ♰ ♽ ⨷ ⮾ 𝛩 𝛳 𝜃 🄯 🄫 🅒 🜔 ⛔ 🚫 ⚠️ ♻️ 📛
    },
  },

  keys = {
    { "<leader>r", "<cmd>RenderMarkdown toggle<cr>", mode = "n", desc = "Toggle RenderMarkdown" },
  },
}
