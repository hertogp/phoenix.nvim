local M = {}

function M:load()
  for n = 3, 10, 1 do
    table.insert(self, n)
  end
  return self
end

function M:clear()
  while #self > 0 do
    table.remove(self)
  end
end

function M.say()
  print('howdie')
end

function M.bye()
  print('bye bye')
end

-- the test

print('delme got required/reloaded')

return M
