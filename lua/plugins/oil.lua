-- https://github.com/stevearc/oil.nvim

return {

  "stevearc/oil.nvim",
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {
    delete_to_trash = true,
    view_options = {
      show_hidden = true,
    },
    float = {
      padding = 2,
      max_width = 0.6,
      max_height = 0.4,
    },
  },
  -- Optional dependencies
  -- dependencies = { { "echasnovski/mini.icons", opts = {} } },

  dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
  -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  lazy = false,
  keys = {
    { "<space>-", "<cmd>Oil --float<cr>", mode = "n", desc = "Open Oil in floating window" },
  },
}
