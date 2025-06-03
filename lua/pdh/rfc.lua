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
  error('snacks, a dependency, is missing')
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

function H.to_symbol(topic, id)
  -- local symbol = { '', '' }
  local fname = H.to_fname(topic, id)
  if fname and vim.fn.filereadable(fname) == 1 then
    return ''
  else
    return ''
  end
end

function H.fetch(topic, id)
  -- return a, possibly empty, list of lines
  local rv = plenary.curl.get({ url = H.to_url(topic, id), accept = 'plain/text' })

  if rv and rv.status == 200 then
    -- REVIEW: does the \f indeed eliminate the ^L formfeeds
    -- (\12 aka \f aka FF aka 0x0C)?  If so, no need to do that
    -- again in H.save()
    local lines = vim.split(rv.body, '[\r\n\f]')
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
    return idx -- i.e. {}
  end

  if H.ttl(fname) < 0 then
    vim.notify('downloading index for ' .. topic, vim.log.levels.WARN)
    local lines = H.fetch(topic, 'index')

    if #lines == 0 then
      vim.notify('index download failed for ' .. topic, vim.log.levels.ERROR)
      return idx -- i.e. {}
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

  if id ~= 'index' then
    -- only add modeline for rfc, bcp etc.. not for index files
    local modeline = H.modeline(M.config.modeline)
    if modeline then
      lines[#lines + 1] = modeline
    end
  end

  for idx, line in ipairs(lines) do
    -- in snacks.picker.preview.lua, line:find("[%z\1-\8\11\12\14-\31]") -> binary is true
    -- so eleminate (most) control chars (like ^L, aka FormFeed 0xFF, or \12)
    lines[idx] = string.gsub(line, '[%z\1-\8\11\12\14-\31]', '')
  end

  local dir = vim.fs.dirname(fname)
  vim.fn.mkdir(dir, 'p')
  if vim.fn.writefile(lines, fname) < 0 then
    vim.notify('could not write index ' .. topic .. ' to ' .. fname, vim.log.levels.ERROR)
  end

  return fname
end

--[[ Module ]]

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

function M.find()
  local topdir = H.to_dir(M.config.data)
  snacks.picker.files({ hidden = true, cwd = topdir })
end

function M.grep()
  local topdir = H.to_dir(M.config.data)
  snacks.picker.grep({ hidden = true, cwd = topdir })
end

function M.test(topic, id)
  vim.notify('test ' .. topic .. ' ' .. id)
end

function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts)

  return M
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

  -- TODO: replace with snacks picker
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

function M.snack(stream)
  -- Use the source Luke!
  -- * `:!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/preview.lua`
  -- *  ``:!open https://github.com/folke/todo-comments.nvim/blob/main/lua/todo-comments/search.lua`
  -- * `:!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/preview.lua`

  stream = stream or 'rfc'
  local index = H.load_index(stream)

  if #index == 0 then
    vim.notify('argh, indez has 0 entries')
    return
  end

  local items = {}
  local name_width = 3 + #('' .. #index) + 2 + 4 -- 'rfc' + xxxx + 2 + '.txt'
  for i, line in ipairs(index) do
    local topic, id, text = H.entry_parse(line)
    local fname = H.to_fname(topic, id)
    if topic and id and text then
      table.insert(items, {
        -- insert an Item
        idx = i,
        score = i,
        text = text,
        name = string.format('%s%d.txt', topic, id),
        -- file is used for preview
        file = fname,
        -- extra
        exists = fname and vim.fn.filereadable(fname) == 1,
        topic = topic,
        id = id,
        symbol = H.to_symbol(topic, id),
      })
    else
      vim.notify('ill formed index entry ' .. vim.inspect(line), vim.log.levels.WARN)
    end
  end

  return snacks.picker({
    items = items,
    layout = {
      fullscreen = true,
      -- preset = 'ivy_split',
      -- preview = 'main',
    },
    format = function(item)
      -- format an item for display in picker list
      -- return list: { { str1, hl_name1 }, { str2, hl_nameN }, .. }
      local hl_item = (item.exists and 'SnacksPickerCode') or 'SnacksPicker'
      vim.print('hl_item ' .. hl_item)
      local ret = {}
      ret[#ret + 1] = { item.symbol, hl_item }
      ret[#ret + 1] = { (' %-' .. name_width .. 's'):format(item.name), '' }
      ret[#ret + 1] = { H.sep, 'SnacksWinKeySep' }
      ret[#ret + 1] = { item.text, '' }
      return ret
    end,
    confirm = function(picker, item)
      vim.notify(picker:count() .. ' items in selection')
      picker:close()
      if vim.fn.filereadable(item.file) == 0 then
        vim.notify('downloading ' .. item.name)
        local lines = H.fetch(item.topic, item.id)
        H.save(item.topic, item.id, lines)
      end
      vim.cmd('edit ' .. item.file)
    end,
  })
end
return M
