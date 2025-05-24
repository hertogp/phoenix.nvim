--[[

Easily search, download and read ietf rfc's.

fuzzy> 'bgp !info 'path | 'select
- 'str match exact occurrences
- !str exclude exact occurrences
- ^str match exact occurrences at start of the string
- str$ match exact occurrences at end of the string
- | acts as OR operator: ^core go$ | rb$ | py$ <- match entries that start with core and end with either go, rb or py
- fzf -e or --exact uses exact matching; '-prefix unquotes the term

--]]

--[[ dependency check ]]

-- :lua =R('pdh.rfc') to reload package after modifications were made

local M = {} -- module to be returned
local H = {} -- private helpers

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

H.valid = { rfc = true, bcp = true, std = true, fyi = true, ien = true }

function H.ttl(fname)
  -- remaining seconds to live
  return M.config.ttl + vim.fn.getftime(fname) - vim.fn.localtime()
end

function H.to_index(topic, lines)
  -- collect eligible lines and format as entries
  -- 1. a line that starts with a number, starts a candidate entry
  -- 2. a line that does not start with a number is added to the current candidate
  -- 3. candidates that do not start with a number are eliminated
  -- ien index: nrs donot start at first column ... so this will fail
  local idx = { '' }
  local fmt = function(head, candidate)
    local nr, rest = string.match(candidate, '^(%d+)%s+(.*)')
    if nr ~= nil then
      return string.format('%3s|%05d| %s', head, tonumber(nr), rest)
    end
    return nil -- this will cause candidate deletion
  end

  -- traverse only once
  for _, line in ipairs(lines) do
    if string.match(line, '^%d') then
      -- format current entry, then start new entry
      idx[#idx] = fmt(topic, idx[#idx])
      idx[#idx + 1] = line
    elseif string.match(line, '^%s+') then
      -- accumulate in new candidate
      -- TODO: do we actually need to check for starting whitespace?
      idx[#idx] = idx[#idx] .. ' ' .. vim.trim(line)
    end
  end

  -- also format last accumulated candidate (possibly deleting it)
  idx[#idx] = fmt(topic, idx[#idx])
  vim.notify('index ' .. topic .. ' has ' .. #idx .. ' entries', vim.log.levels.WARN)
  return idx
end

function H.to_fname(topic, id)
  -- return full file path for (topic, id) or nil
  local fdir, fname
  local cfg = M.config
  local top = M.config.top or 'ietf.org'

  if not H.valid[topic] then
    return nil
  end

  if id == 'index' then
    -- it's an document index
    fdir = cfg.cache
    fname = vim.fs.joinpath(fdir, top, string.format('%s-index.txt', topic))
    return vim.fs.normalize(fname)
  end

  -- it's an ietf document
  if type(cfg.data) == 'table' then
    -- find root dir based on markers in cfg.data
    fdir = vim.fs.root(0, cfg.data)
  end

  fdir = fdir or cfg.data or vim.fn.stdpath('data')
  id = tonumber(id)
  fname = vim.fs.joinpath(fdir, top, topic, string.format('%s%d.txt', topic, id))

  return vim.fs.normalize(fname)
end

function H.to_url(topic, id)
  -- return url for an item or index, format is:
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
    -- removes leading zero's, so 0009 -> 9
    return string.format('%s/%s/%s%d.txt', base, topic, topic, id)
  end

  error('id must be one of: "index" or a number')
end

function H.fetch(topic, id)
  -- return a, possibly empty, list of lines
  local rv = plenary.curl.get({ url = H.to_url(topic, id), accept = 'plain/text' })

  if rv and rv.status == 200 then
    local lines = vim.split(rv.body, '[\r\n]')
    return lines
  else
    vim.notify('failed to download ' .. topic .. ' id ' .. id, vim.log.levels.WARN)
    return {}
  end
end

function H.load_index(topic)
  -- loads index for topic, downloading it if needed
  -- fname can be too old, be missing, have 0 bytes ...
  local idx = {} -- empty means failure
  local fname = H.to_fname(topic, 'index')

  if not H.valid[topic] or fname == nil then
    return idx
  end

  if H.ttl(fname) < 0 then
    vim.notify('downloading index for ' .. topic, vim.log.levels.WARN)
    local lines = H.fetch(topic, 'index')

    if #lines == 0 then
      vim.notify('index download failed for ' .. topic, vim.log.levels.ERROR)
      return idx
    end

    idx = H.to_index(topic, lines)
    vim.notify('index has ' .. #idx .. ' entries')
    H.save(topic, 'index', idx)
    return idx
  else
    idx = vim.fn.readfile(fname) -- failure to read returns empty list
    if #idx == 0 then
      vim.notify('could not read ' .. fname, vim.log.levels.WARN)
    end
    return idx
  end
end

function H.save(topic, id, lines)
  local fname = H.to_fname(topic, id)

  if fname == nil then
    return fname
  end

  local dir = vim.fs.dirname(fname)
  vim.fn.mkdir(dir, 'p')
  if vim.fn.writefile(lines, fname) < 0 then
    vim.notify('could not write index ' .. topic .. ' to ' .. fname, vim.log.levels.ERROR)
  end

  return fname
end

--[[ Module ]]

function M.reload()
  return require('plenary.reload').reload_module('pdh.rfc')
end

function M.search(stream)
  -- search indices and download selection from ietf
  stream = stream or 'rfc'
  local index = H.load_index(stream)

  if #index == 0 then
    vim.notify('no index available for ' .. stream, vim.log.levels.ERROR)
    return
  end

  fzf_lua.fzf_exec(index, {
    prompt = 'search> ',
    winopts = {
      wrap = true,
      title = '| ietf |',
      border = 'rounded',
    },
    actions = {
      default = function(selected)
        -- this is actually ["ctrl-m"]
        local topic, id = unpack(vim.split(selected[1], '|'))
        vim.notify('url ' .. H.to_url(topic, id) .. ' -> ' .. H.to_fname(topic, id))
        local rv = H.fetch(topic, id)
        local fname = H.save(topic, id, rv)
        vim.cmd('e ' .. fname)
      end,
    },
  })
end

function M.test(topic, id)
  vim.notify('test ' .. topic .. ' ' .. id)
  local lines = {
    '   1 this should be skipped',
    '   this one as well',
    '',
    '01 line 1',
    '     line 1.1',
    '     line 1.2',
    '',
    '02 line 2',
    '     line 2.1',
  }
  -- join subsequent lines until line starts with a number
  local idx = { '' } -- start with empty first line
  local fmt = function(head, line)
    local nr, rest = string.match(line, '^(%d+)%s+(.*)')
    if nr ~= nil then
      return string.format('%3s|%05d| %s', head, nr, rest)
    end
    return nil
  end

  for _, line in ipairs(lines) do
    if string.match(line, '^%d') then
      -- before starting a new index entry, prep the current one
      idx[#idx] = fmt(topic, idx[#idx])
      idx[#idx + 1] = line
    elseif string.match(line, '^%s+') then
      idx[#idx] = idx[#idx] .. ' ' .. vim.trim(line)
    end
  end
  -- don't forget the last one
  idx[#idx] = fmt(topic, idx[#idx])
  P(idx)
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
