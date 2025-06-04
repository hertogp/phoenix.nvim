--[[

Easily search, download and read ietf rfc's.

fuzzy> 'bgp !info 'path | 'select
- 'str match exact occurrences
- !str exclude exact occurrences
- ^str match exact occurrences at start of the string
- str$ match exact occurrences at end of the string
- | acts as OR operator: ^core go$ | rb$ | py$ <- match entries that start with core and end with either go, rb or py

TODO: these need some TLC
- [x] parse an entry into topic|nr|title|status|formats|doi|updates|updated_by|obsoletes|obsoleted_by
      - status and other known (label ..) are parsed into tags for an entry & removed from display
      - this is parsed when loading index for searching, rather than when saving index to disk
- [ ] formats other than TXT are redirected to browser w/ a URL (.pdf, .html etc..) or the info page
      e.g. https://www.editor-rfc.org/info/rfc8  (no extension)
- [ ] info page the default when choosing to browse for an rfc, rather than downloading it?
- [ ] no local file, just show the item without the error msg.  Howto avoid that error?
- [ ] when download fails, flash a warning and do not create a local file with just a modeline.
- [ ] how to handle icons properly?

--]]

--[[ dependency check ]]

-- :lua =R('pdh.rfc') to reload package after modifications were made

local M = {} -- module to be returned
local H = {} -- private helpers

--[[ locals ]]

local ok, plenary, snacks

ok, plenary = pcall(require, 'plenary')
if not ok then
  error('plenary, a dependency, is missing')
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
        vim.notify('modeline: ignoring unknown option ' .. vim.inspect(k), vim.log.levels.WARN)
      end
    end
    if #opts > 0 then
      return string.format('/* vim: set%s: */', opts)
    end
  end

  return nil -- do not add modeline
end

function H.title_parse(line)
  -- take out all (tag: stuff) and (word word words) parts
  -- (Status: ..) (Format: ..) (DOI: ..)
  -- (Obsoletes rfc..) (Obsoleted by rfc...)
  -- (Updates rfc...) (Updated by rfc ..)
  -- vim.split
  local tags = {}
  local wanted = {
    obsoletes = true,
    obsoleted_by = true,
    updates = true,
    updated_by = true,
    also = true,
    status = true,
    format = true,
    doi = true,
  }

  for part in string.gmatch(line, '%(([^)]+)%)') do
    local part2 = string.gsub(part, '%s+by', '_by', 1):gsub(':', '', 1)
    local k, v = string.match(part2, '^([^%s]+)%s+(.*)$')
    if k and v and wanted[k:lower()] then
      tags[k:lower()] = vim.trim(v:lower())
      line = string.gsub(line, '%s%(' .. part .. '%)', '', 1)
    end
  end

  return line, tags
end

function H.idx_entry_build(topic, line)
  -- return string formatted like 'topic|nr|text' or nil
  -- topic|nr|text
  local nr, rest = string.match(line, '^%s*(%d+)%s+(.*)')

  if nr ~= nil then
    return string.format('%3s%s%05d%s%s', topic, H.sep, tonumber(nr), H.sep, rest)
  end
  return nil -- this will cause candidate deletion
end

function H.idx_entry_parse(line)
  -- break a selected entry 'topic|nr|text' into its consituents
  return unpack(vim.split(line, H.sep))
end

function H.idx_build(topic, lines)
  -- downloaded topic-index.txt lines -> formatted index lines (stream|nr|text)
  -- collect eligible lines and format as entries
  -- --------------------- example
  -- 0001 this is the
  --      title of rfc 1
  -- ---------------------
  -- 1. a line that starts with a number (ignoring leading wspace), starts a candidate entry
  -- 2. a line that does not start with a number is added to the current candidate
  -- 3. candidates that do not start with a number are eliminated
  -- ien index: nrs donot start at first column ... so this will fail
  local idx = { '' }

  for _, line in ipairs(lines) do
    if string.match(line, '^%s*%d+%s') then
      -- format current entry, then start new entry
      idx[#idx] = H.idx_entry_build(topic, idx[#idx])
      idx[#idx + 1] = line
    elseif string.match(line, '^%s+') then
      -- accumulate in new candidate
      -- TODO: do we actually need to check for starting whitespace?
      idx[#idx] = idx[#idx] .. ' ' .. vim.trim(line)
    end
  end

  -- also format last accumulated candidate (possibly deleting it)
  idx[#idx] = H.idx_entry_build(topic, idx[#idx])
  vim.notify('index ' .. topic .. ' has ' .. #idx .. ' entries', vim.log.levels.WARN)
  return idx
end

function H.idx_parse(index)
  -- index is list of formatted index lines (stream|nr|text)
  -- return list of { {topic, id, text}, .. }
  local idx = {}
  for _, line in ipairs(index) do
    local topic, id, text = H.idx_entry_parse(line)
    if topic and id and text then
      idx[#idx + 1] = { topic, id, text }
    else
      vim.notify('[error] ill-formed index line ' .. line, vim.log.levels.WARN)
    end
  end
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
  local url = H.to_url(topic, id)
  local rv = plenary.curl.get({ url = url, accept = 'plain/text' })

  if rv and rv.status == 200 then
    -- no newline's for buf set lines, no formfeed for snacks preview
    local lines = vim.split(rv.body, '[\r\n\f]')
    vim.notify('downloaded ' .. topic .. ' (' .. #lines .. 'lines)')
    return lines
  else
    vim.notify('[failed] status: ' .. rv.status .. ' for ' .. url, vim.log.levels.WARN)
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

  if H.ttl(topic) < 0 then
    vim.notify('downloading index for ' .. topic, vim.log.levels.WARN)
    local lines = H.fetch(topic, 'index')

    if #lines == 0 then
      vim.notify('index download failed for ' .. topic, vim.log.levels.ERROR)
      return idx -- i.e. {}
    end

    idx = H.idx_build(topic, lines)
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

--[[ H mod new]]
-- helper functions for small tasks
-- note that caller is assumed to check validity of args and values
-- so here we `assert` and possibly fail hard

function H.fname(stream, id)
  assert(H.valid[stream])

  -- return full file path for (stream, id) or nil
  id = id or 'index'
  local fdir, fname
  local cfg = M.config
  local top = M.config.top or H.top

  if id == 'index' then
    -- it's an document index
    fdir = cfg.cache
    fname = vim.fs.joinpath(fdir, top, string.format('%s-index.txt', stream))
    return vim.fs.normalize(fname)
  end

  -- id is an ietf document number
  id = tonumber(id) -- eliminate leading zero's (if any)
  assert(id)

  -- find fdir based on markers
  if type(cfg.data) == 'table' then
    fdir = vim.fs.root(0, cfg.data)
  end

  fdir = fdir or cfg.data or vim.fn.stdpath('data')
  fname = vim.fs.joinpath(fdir, top, stream, string.format('%s%d.txt', stream, id))

  return vim.fs.normalize(fname)
end

function H.save(stream, id, lines)
  -- save to disk, creating directory as needed
  local fname = H.fname(stream, id)

  if fname == nil then
    return fname
  end

  if id ~= 'index' then
    -- only add modeline for rfc, bcp etc.. not for index files
    lines[#lines + 1] = '/* vim: set ft=rfc: */'
  end

  for idx, line in ipairs(lines) do
    -- snacks.picker.preview.lua, line:find("[%z\1-\8\11\12\14-\31]") -> binary is true
    -- so keep snacks happy
    lines[idx] = string.gsub(line, '[%z\1-\8\11\12\14-\31]', '')
  end

  local dir = vim.fs.dirname(fname)
  vim.fn.mkdir(dir, 'p')
  if vim.fn.writefile(lines, fname) < 0 then
    vim.notify('could not write index ' .. stream .. ' to ' .. fname, vim.log.levels.ERROR)
  end

  return fname
end

function H.ttl(stream)
  -- remaining TTL [seconds], fname not found, getftime will be -1
  local fname = H.fname(stream)
  local ttl = M.config.ttl or 0
  return ttl + vim.fn.getftime(fname) - vim.fn.localtime()
end

function H.url(stream, id, ext)
  -- returns url for stream document or its index
  assert(H.valid[stream]) -- would be internal error

  ext = ext or 'txt'
  local base = 'https://www.rfc-editor.org'
  local fmt
  if id == 'index' then
    fmt = '%s/%s/%s-%s.%s' -- base/stream/stream-index.ext
  else
    id = tonumber(id) -- assume pos integer, no floats
    assert(id)
    fmt = '%s/%s/%s%d.%s' -- base/stream/stream<id>.ext
  end

  return string.format(fmt, base, stream, stream, id, ext)
end

function H.curl(url)
  -- return a, possibly empty, list of lines
  local rv = plenary.curl.get({ url = url, accept = 'plain/text' })
  local lines = {}

  if rv and rv.status == 200 then
    -- no newline's for buf set lines, no formfeed for snacks preview
    lines = vim.split(rv.body, '[\r\n\f]')
  end
  return { status = rv.status, lines = lines }
end

--[[ INDEX ]]
-- functions that work with the indices of streams of ietf documents

local Idx = {}

function Idx.curl(stream)
  -- retrieve index from rfc-editor -> { {stream, nr, text}, .. }
  if not H.valid[stream] then
    vim.notify('[warn] stream ' .. vim.inspect(stream) .. 'not supported', vim.log.levels.WARN)
    return {}
  end

  -- retrieve raw content
  local url = H.url(stream, 'index')
  local rv = H.curl(url)
  if rv.status ~= 200 then
    vim.notify('[warn] download failed: [' .. rv.status .. '] ' .. url, vim.log.levels.ERROR)
    return {}
  end

  -- prep the raw input lines
  local lines = {}
  for _, line in ipairs(lines) do
    ::next::
  end

  -- parse raw, assembled, content line
  local parse = function(line)
    local nr, title = string.match(line, '^%s*(%d+)%s+(.*)')
    nr = tonumber(nr) -- eleminate any leading zero's
    if nr ~= nil then
      return { stream, nr, title }
    end
    return nil -- won't add the candidate
  end

  -- build parsed entries
  local idx = {} -- parsed content { {s, n, t}, ... }
  local acc = '' -- accumulating content
  for _, line in ipairs(rv.lines) do
    if string.match(line, '^%s*%d+%s') then
      idx[#idx + 1] = parse(acc)
      acc = line -- start new accumulator
    elseif string.match(line, '^%s+') then
      acc = acc .. ' ' .. vim.trim(line)
    end
  end
  -- don't forget the last entry
  idx[#idx + 1] = parse(acc)

  return idx -- { {stream, nr, title }, .. }
end

function Idx.get(stream)
  -- get a single stream, either from disk or from ietf
  assert(H.valid[stream])

  local idx = {}

  if H.ttl(stream) < 1 then
    -- idx on disk either too old or doesn't exist
    idx = Idx.curl(stream)
    Idx.save(idx)
  else
    idx = Idx.read(stream)
  end

  return idx
end

function Idx.index(streams)
  -- returns { {stream<1>, nr, title}, ... {stream<n>, nr, title} }
  streams = streams or { 'rfc' }
  local idx = {}
  for _, stream in ipairs(streams) do
    assert(H.valid[stream])
    for _, entry in ipairs(Idx.get(stream)) do
      idx[#idx + 1] = entry
    end
  end
  return idx
end

function Idx.read(stream)
  -- read an index from disk, don't mind the ttl at this point
  assert(H.valid[stream])

  local fname = H.fname(stream, 'index')
  local idx = {}

  local lines = vim.fn.readfile(fname) -- failure to read returns empty list
  for _, line in ipairs(lines) do
    idx[#idx + 1] = vim.split(line, H.sep) -- Itm.parse
  end
  return idx
end

function Idx.save(idx)
  -- save index entries to their respective <stream>-index files on disk
  local streams = {}
  for _, entry in ipairs(idx) do
    local stream, nr, title = unpack(entry)
    local sep = H.sep
    local line = string.format('%s%s%d%s%s', stream, sep, nr, sep, title)

    if streams[stream] == nil then
      streams[stream] = {} -- add table for new stream
    end

    table.insert(streams[stream], line)
  end

  for stream, lines in pairs(streams) do
    H.save(stream, 'index', lines)
  end
end

--[[
idx_curl(stream)      : raw -> idx = { {s,n,t}, ..}
idx_save(idx)         : idx = { {s,n,t}, ..} -> disk by <s>-index.txt
idx_read(stream)      : disk -> idx = { {s,n,t} .. }
idx_items(idx}        : { {s,n,t}, .. } -> { items } (t is parsed, fields added)

itm_curl
itm_save
itm_read
itm_item

ttl(fname, max_age) -> remaining seconds
curl(url) -> rv {status=.., content=lines}
save(fname, lines) -> ok, #lines
read(fname) -> lines -> ok, lines


--]]
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

function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts)

  return M
end

function M.search(stream)
  -- search the stream(s) index/indices
  -- TODO:
  -- [ ] arg maybe streams, e.g. {'rfc', 'bcp', 'std'} and concat the index lists of named topics
  -- [x] use H.sep instead of magical '|' char
  -- [x] idx_entry_build(topic, line)  & idx_entry_parse(entry) -> topic, id
  -- Use the source Luke!
  -- * `:!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/preview.lua`
  -- *  ``:!open https://github.com/folke/todo-comments.nvim/blob/main/lua/todo-comments/search.lua`
  -- * `:!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/preview.lua`

  stream = stream or 'rfc'
  local index = H.load_index(stream)

  if #index == 0 then
    vim.notify('[warn] index ' .. stream .. ' has 0 entries', vim.log.levels.WARN)
    return
  end

  local items = {}
  local name_width = 3 + #tostring(#index) + 4 + 1 -- '<rfc><xxxx><.txt>' + 1
  local name_fmt = ' %-' .. name_width .. 's'

  for i, line in ipairs(index) do
    local topic, id, text = H.idx_entry_parse(line)
    if topic and id and text then
      local fname = H.to_fname(topic, id)
      local title, labels = H.title_parse(text)
      if #title < 1 then
        vim.print(vim.inspect({ 'title', title, labels }))
      end

      table.insert(items, {
        -- insert an Item
        idx = i,
        score = i,
        text = title,
        name = string.format('%s%d.txt', topic, id), -- TODO: .txt available?
        file = fname, -- used for preview

        -- extra
        labels = labels,
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
    -- TODO: tie actions (f=fetch, F=fetch selection, etc..) to keys, but how?
    -- see `!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/config/defaults.lua`
    -- around Line 200, win = { input = { keys = { ... }}}
    win = {
      list = {
        -- this is the window where list being search/filtered is displayed
        -- ('/' toggle focus between list/input window)
        -- <c-g/G> originally toggles live_grep which is not supported in
        -- search anyway.  Hmm. can't override it here.
        keys = {
          -- [<TAB>] is select_and_next, will select an item (input/list win)
          ['<c-x>'] = { 'download', mode = { 'n', 'i' } },
          ['<c-m-x>'] = { 'download_selection', mode = { 'n', 'i' } },
        },
      },
      input = {
        keys = {
          ['<c-x>'] = { 'download', mode = { 'n', 'i' } },
          ['<c-m-x>'] = { 'download_selection', mode = { 'n', 'i' } },
          ['<c-y>'] = { 'echo', mode = { 'n', 'i' } },
        },
      },
    },

    actions = {
      download = function(picker, item)
        vim.print({ 'download item', vim.inspect(item) })
      end,

      download_selection = function(picker, item)
        -- item is current item in the list
        -- picker.list.selected is list of selected items
        local x = picker.list.selected
        vim.print({
          'download selection (' .. #x .. 'items)',
          'item is',
          vim.inspect(item),
          'selection is',
          vim.inspect(x),
        })
      end,

      echo = function(picker)
        vim.print({ 'echo', vim.inspect(picker) })
      end,
    },

    layout = {
      fullscreen = true,
    },
    format = function(item)
      -- format an item for display in picker list
      -- return list: { { str1, hl_name1 }, { str2, hl_nameN }, .. }
      -- `!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/format.lua`
      local hl_item = (item.exists and 'SnacksPickerCode') or 'SnacksPicker'
      local ret = {}
      ret[#ret + 1] = { item.symbol, hl_item }
      ret[#ret + 1] = { name_fmt:format(item.name), hl_item }
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
        if #lines > 0 then
          H.save(item.topic, item.id, lines)
          vim.cmd('edit ' .. item.file)
        end
      else
        vim.cmd('edit ' .. item.file)
      end
    end,
  })
end

function M.test()
  local idx = Idx.index({ 'ien' })
  for _, itm in ipairs(idx) do
    vim.print(vim.inspect(itm))
  end
end

return M
