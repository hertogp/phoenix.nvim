-- File:  luasnip-config.lua
-- https://github.com/L3MON4D3/LuaSnip
-- https://github.com/molleweide/LuaSnip-snippets.nvim  (a collection of snippets)
-- see ~/.config/nvim/after/plugin/luasnip.lua (reload with <leader>ss)
local ls = require "luasnip"
local types = require "luasnip.util.types"

ls.config.set_config {
  -- keep the last snippet around so you can jump back into it
  history = true,

  -- dynamic snippet updates as you type
  updateevents = "TextChanged,TextChangedI",

  -- autosnippets
  enable_autosnippets = true,

  ext_opts = {
    [types.choiceNode] = {
      active = { virt_text = { { "← Ctrl-L cycles choices, <TAB> moves on", "Error" } } },
    },
  },

  -- so we can call setup_snip_env in a lua snippets file
  snip_env = ls.get_snip_env(),
}
