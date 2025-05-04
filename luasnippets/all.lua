-- File: ~/.config/nvim/luasnippets/all.lua

--[[ ALL snippets ]]

print "loading snippets from all.lua"

local t = require "luasnippets.import"

--[[ helpers ]]

local fname = function()
  local home = vim.fn.expand "$HOME"
  local path = vim.fn.expand(vim.api.nvim_buf_get_name(0))
  return "File: " .. string.gsub(path, "^" .. home, "~")
end

--[[ snippets ]]

return {

  t.snippet("xxx", {
    t.c(1, { t.t "-- FIXME: ", t.t "-- XXX: ", t.t "-- TODO: " }),
  }),

  t.snippet({
    trig = "file:",
    name = "File:",
    desc = "expands to filename of current buffer (if any)",
  }, {
    t.f(fname, {}),
  }),
}
