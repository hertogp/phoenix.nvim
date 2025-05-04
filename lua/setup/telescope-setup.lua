-- File: telescope.lua
-- https://github.com/nvim-telescope/telescope.nvim
require("telescope").setup {
  -- in normal mode, 'q' quits telescope (see :h telescope.mappings)
  -- this should probably move to lua/setup/telescope.lua file.
  defaults = {
    mappings = { n = { ["q"] = "close" } },
    sorting_strategy = "ascending",
  },
  extensions = {
    heading = {
      treesitter = true,
    },
  },
}

require("telescope").load_extension "fzf"
require("telescope").load_extension "file_browser"
require("telescope").load_extension "heading"
require("telescope").load_extension "dap"
