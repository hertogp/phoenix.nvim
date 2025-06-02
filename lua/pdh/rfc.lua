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

local ok, plenary, fzf_lua, snacks

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

ok, snacks = pcall(require, 'snacks')
if not ok then
  error('fzf-lua, a dependency, is missing')
  return
end

--[[ Helpers ]]

H.valid = { rfc = true, bcp = true, std = true, fyi = true, ien = true }
H.top = 'ietf.org'
H.sep = '│'

function H.ttl(fname)
  -- remaining seconds to live
  return M.config.ttl + vim.fn.getftime(fname) - vim.fn.localtime()
end

function H.modeline(spec)
  -- returns modeline string if possible, nil otherwise
  if type(spec) == 'string' then
    -- use verbatim
    return spec
  end

  if type(spec) == 'table' then
    -- build modeline, ignore unknown options
    local opts = ''
    for k, v in pairs(spec) do
      if vim.fn.exists(string.format('&%s', k)) == 1 then
        opts = string.format('%s %s=%s', opts, k, v)
      else
        vim.notify('modeline: ignore unknown option ' .. vim.inspect(k), vim.log.levels.ERROR)
      end
    end
    if #opts > 0 then
      return string.format('/* vim: set%s: */', opts)
    end
  end

  return nil -- do not add modeline
end

function H.entry_build(topic, line)
  -- return string formatted like 'topic|nr|text' or nil
  local nr, rest = string.match(line, '^(%d+)%s+(.*)')
  if nr ~= nil then
    return string.format('%3s%s%05d%s %s', topic, H.sep, tonumber(nr), H.sep, rest)
  end
  return nil -- this will cause candidate deletion
end

function H.entry_parse(line)
  -- break a selected entry 'topic|nr|text' into its consituents
  return unpack(vim.split(line, H.sep))
end
function H.to_index(topic, lines)
  -- collect eligible lines and format as entries
  -- 1. a line that starts with a number, starts a candidate entry
  -- 2. a line that does not start with a number is added to the current candidate
  -- 3. candidates that do not start with a number are eliminated
  -- ien index: nrs donot start at first column ... so this will fail
  local idx = { '' }

  -- traverse only once
  for _, line in ipairs(lines) do
    if string.match(line, '^%d') then
      -- format current entry, then start new entry
      idx[#idx] = H.entry_build(topic, idx[#idx])
      idx[#idx + 1] = line
    elseif string.match(line, '^%s+') then
      -- accumulate in new candidate
      -- TODO: do we actually need to check for starting whitespace?
      idx[#idx] = idx[#idx] .. ' ' .. vim.trim(line)
    end
  end

  -- also format last accumulated candidate (possibly deleting it)
  idx[#idx] = H.entry_build(topic, idx[#idx])
  vim.notify('index ' .. topic .. ' has ' .. #idx .. ' entries', vim.log.levels.WARN)
  return idx
end

function H.to_dir(spec)
  -- find root dir or use spec if valid, fallback is stdpath data dir
  local path
  local top = M.config.top or H.top

  if type(spec) == 'table' then
    -- find root dir based on markers in cfg.data
    path = vim.fs.root(0, spec)
  elseif type(spec) == 'string' then
    path = vim.fs.normalize(spec)
  end

  if path == nil or vim.fn.filereadable(path) == 0 then
    path = vim.fn.stdpath('data')
  end

  -- path = (path and vim.fn.filereadable(path)) or vim.fn.stdpath('data')
  return vim.fs.joinpath(path, top)
end

function H.to_fname(topic, id)
  -- return full file path for (topic, id) or nil
  local fdir, fname
  local cfg = M.config
  local top = M.config.top or H.top

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
  -- return url for an item or index
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
  -- save to disk, creating directory as needed
  local fname = H.to_fname(topic, id)

  if fname == nil then
    return fname
  end

  local modeline = H.modeline(M.config.modeline)
  if modeline then
    lines[#lines + 1] = modeline
  end

  local dir = vim.fs.dirname(fname)
  vim.fn.mkdir(dir, 'p')
  if vim.fn.writefile(lines, fname) < 0 then
    vim.notify('could not write index ' .. topic .. ' to ' .. fname, vim.log.levels.ERROR)
  end

  return fname
end

--[[ Module ]]
--TODO:
-- [ ] H.grep -> grep through doc's in data dir

M.config = {
  cache = vim.fn.stdpath('cache'), -- store indices only once
  data = vim.fn.stdpath('data'), -- path or markers
  -- data = { '.git', '.gitignore' },
  top = 'ietf.org',
  ttl = 7 * 24 * 3600, -- time-to-live [second], before downloading again
  edit = 'tabedit ',
  modeline = {
    ft = 'rfc',
  },
}

function M.reload()
  -- for developing
  return require('plenary.reload').reload_module('pdh.rfc')
end

function M.search(stream)
  -- search the index for `stream`
  -- TODO:
  -- [ ] arg maybe streams, e.g. {'rfc', 'bcp', 'std'} and concat the index lists of named topics
  -- [x] use H.sep instead of magical '|' char
  -- [x] entry_format(topic, id, text)  & entry_parse(entry) -> topic, id

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
        -- this is actually ["ctrl-m"], selected is a list of 1 string
        local topic, id, _ = H.entry_parse(selected[1])
        local edit = M.config.edit or 'e '
        vim.notify('url ' .. H.to_url(topic, id) .. ' -> ' .. H.to_fname(topic, id))
        local rv = H.fetch(topic, id)
        local fname = H.save(topic, id, rv)
        vim.cmd(edit .. fname)
      end,
      ['ctrl-x'] = function(selected)
        local topic, id, _ = H.entry_parse(selected[1])
        local url = H.to_url(topic, id)
        if url ~= nil then
          vim.ui.open(url)
        else
          vim.notify('cannot open ' .. vim.inspect({ topic, id, url }))
        end
      end,
    },
  })
end

function M.find()
  local topdir = H.to_dir(M.config.data)
  -- fzf_lua.files({ hidden = true, cwd = topdir })
  snacks.picker.files({ hidden = true, cwd = topdir })
end

function M.grep()
  local topdir = H.to_dir(M.config.data)
  -- fzf_lua.live_grep({ hidden = true, cwd = topdir })
  snacks.picker.grep({ hidden = true, cwd = topdir })
end

function M.test(topic, id)
  vim.notify('test ' .. topic .. ' ' .. id)
end

function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts)

  return M
end

return M
