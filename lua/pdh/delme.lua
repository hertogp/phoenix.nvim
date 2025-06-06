local M = {}

function M:load()
  for n = 1, 10, 1 do
    table.insert(self, n)
  end
  return self
end

function M:clear()
  while #self > 0 do
    table.remove(self)
  end
end

-- the test

M:load()

for k, v in ipairs(M) do
  vim.print(vim.inspect({ '1-ipairs', k, v }))
end

M:clear()

for k, v in ipairs(M) do
  vim.print(vim.inspect({ '2-ipairs', k, v }))
end

return M
