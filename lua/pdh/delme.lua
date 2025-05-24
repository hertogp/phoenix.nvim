local curl = require('plenary').curl

local M = {}

function M.get(rfcnr)
  local url = 'https://www.rfc-editor.org/rfc/rfc' .. rfcnr .. '.txt'
  local accept = 'text/html'

  local rv = curl.head({ url = url, accept = accept })
  if rv.status == 200 then
    return rv.body
  else
    return ''
  end
end

return M
