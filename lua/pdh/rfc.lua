--[[

Easily search, download and read ietf rfc's.

--]]

--[[ dependency check ]]

-- :lua =R('pdh.rfc') to reload package after modifications were made

local M = {} -- module to be returned
local H = {} -- local helpers

--[[ locals ]]

local ok, plenary, fzf_lua
ok, plenary = pcall(require, 'plenary')
if not ok then
  error('plenary, a dependency, is missing')
  return
end

ok, fzf_lua = pcall(require, 'fzf-lua')
if not ok then
  error('fzf-lua, a dependency, is missing')
  return
end

--[[ Helpers ]]

H.curl = plenary.curl
H.valid = { rfc = true, bcp = true, std = true, fyi = true, ien = true }

function H.expand(dir)
  local path = dir

  if type(dir) == 'table' then
    -- try to find project directory based on markers
    path = vim.fs.root(0, dir)
  end

  if path == nil then
    -- if dir was nil or no project dir found, fallback to 'data' dir
    path = vim.fn.stdpath('data')
  end

  return vim.fs.normalize(path)
end

function H.file_age(path)
  local age = vim.fn.localtime() - vim.fn.getftime(H.expand(path))
  print(string.format('age: %d [s] aka %d [hrs]', age, age / 3600))
end

function H.file_name(topic, id)
  local fname
  local cfg = M.config

  if not H.valid[topic] then
    vim.notify('topic %s is not supported', topic)
    return ''
  end

  if id == 'index' then
    fname = vim.fs.joinpath(cfg.cache, cfg.top, string.format('%s-index.txt', topic))
  else
    id = tonumber(id)
    local dta = H.expand(cfg.data)
    fname = vim.fs.joinpath(dta, cfg.top, topic, string.format('%s%d.txt', topic, id))
  end

  return H.expand(fname)
end

function H.get(topic, id)
  -- TODO: get(topic, id) or get(url)
  local url = H.url(topic, id)

  local rv = H.curl.get({ url = url, accept = 'plain/text' })
  if rv and rv.status == 200 then
    return rv
  else
    vim.notify('failed to download ' .. url, vim.log.levels.WARN)
    return { body = '', status = 504, exit = 1, headers = {} }
  end
end

function H.url(topic, id)
  -- return url for an item or index, format is:
  -- https://www.rfc-editor.org/<topic>/<topic>-index.txt
  -- https://www.rfc-editor.org/<topic>/<topic><nr>.txt
  -- https://www.rfc-editor.org/rfc/rfc<nr>.json

  local base = 'https://www.rfc-editor.org'
  topic = string.lower(topic)

  if not H.valid[topic] then
    error('topic must one of: rfc, bcp, std, fyi or ien')
  end

  if id == 'index' then
    return string.format('%s/%s/%s-%s.txt', base, topic, topic, id)
  end

  id = tonumber(id)
  if id ~= nil then
    -- avoid leading zero's, so 0009 -> 9
    return string.format('%s/%s/%s%d.txt', base, topic, topic, id)
  end

  error('id must be one of: "index" or a number')
end

function H.save(topic, id, rv)
  local fname = H.file_name(topic, id)
  local dir = vim.fs.dirname(fname)
  vim.fn.mkdir(dir, 'p')
  local fh = io.open(fname, 'w')
  if fh ~= nil then
    fh:write(rv.body)
    fh:close()
  else
    vim.notify('could not write to ' .. fname, vim.log.levels.WARN)
  end
  return fname
end

--[[ Module ]]

function M.reload()
  return require('plenary.reload').reload_module('pdh.rfc')
end

function M.search()
  -- search indices and download selection from ietf
  local index = {
    'rfc|0001| abc ,sf asf asAddddddddddddddd ddddddddddddddddddd dddddddddddddddddddddddd dddddddddddddddddddddd dddddddddddddddddddddd ddddddddddddddddddfd; jsfl jsfd;lk jasdf;l jasd;lf jasd;lf jas',
    'rfc|0002| asdfasdf ;sdk fwriu w jkshnv ;qwh r[qwiohfsda;kjc qwr hwe',
    'rfc|0099| 0002 xyz',
    'rfc|0999| 0999 rfc999',
    'std|0019| standards track',
    'fyi|0001| a simple fyi',
    'rfc|index| the rfc index',
  }
  fzf_lua.fzf_exec(index, {
    prompt = 'search> ',
    winopts = {
      title = '| ietf |',
      border = 'rounded',
    },
    actions = {
      default = function(selected)
        -- this is acutally ["ctrl-m"]
        -- vim.notify('selected: ' .. vim.inspect(selected))
        local topic, id = unpack(vim.split(selected[1], '|'))
        -- vim.notify('topic ' .. topic .. ', id ' .. tonumber(id))
        vim.notify('url ' .. H.url(topic, id) .. ' -> ' .. H.file_name(topic, id))
        local rv = H.get(topic, id)
        local fname = H.save(topic, id, rv)
        vim.cmd('e ' .. fname)
      end,
    },
  })
end
function M.test(topic, id)
  return H.get(topic, id)
end

M.config = {
  cache = vim.fn.stdpath('cache'), -- store indices only once
  data = vim.fn.stdpath('data'), -- path or markers
  -- data = { '.git', '.gitignore' },
  top = 'ietf.org',
  ttl = 24 * 3600, -- time-to-live in seconds, before refreshing
}

function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts)

  return M
end

return M
