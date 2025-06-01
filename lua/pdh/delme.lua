local M = {}

function M.hi(who)
  vim.print('hi ' .. vim.inspect(who))
end

return M
