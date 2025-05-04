--[[ helper functions ]]

local M = {}
local ls = require "luasnip"
M.snippet = ls.snippet

M.fmt = require("luasnip.extras.fmt").fmt
M.rep = require("luasnip.extras").rep
M.i = ls.i
M.t = ls.text_node
M.c = ls.choice_node
M.f = ls.function_node

return M
