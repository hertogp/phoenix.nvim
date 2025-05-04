-- File: ~/.config/nvim/luasnippets/lua.lua

--[[ LUA SNIPPETS ]]

print "loading snippets from lua.lua"

local t = require "luasnippets.import"

local function last_label(name)
  local parts = vim.split(name[1][1], ".", { plain = true })
  return parts[#parts] or ""
end

return {
  t.snippet(
    "req",
    t.fmt([[local {} = require"{}"]], {
      t.f(last_label, { 1 }),
      t.i(1),
    })
  ),

  t.snippet("--[[", {
    t.t "--[[ ",
    t.i(1),
    t.t " ]]",
  }),
}
