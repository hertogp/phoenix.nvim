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

-- function H.idx_entry_build(topic, line)
--   -- return string formatted like 'topic|nr|text' or nil
--   -- topic|nr|text
--   local nr, rest = string.match(line, '^%s*(%d+)%s+(.*)')
--
--   if nr ~= nil then
--     return string.format('%3s%s%05d%s%s', topic, H.sep, tonumber(nr), H.sep, rest)
--   end
--   return nil -- this will cause candidate deletion
-- end

-- function H.idx_entry_parse(line)
--   -- break a selected entry 'topic|nr|text' into its consituents
--   return unpack(vim.split(line, H.sep))
-- end

-- function H.idx_build(topic, lines)
--   -- downloaded topic-index.txt lines -> formatted index lines (stream|nr|text)
--   -- collect eligible lines and format as entries
--   -- --------------------- example
--   -- 0001 this is the
--   --      title of rfc 1
--   -- ---------------------
--   -- 1. a line that starts with a number (ignoring leading wspace), starts a candidate entry
--   -- 2. a line that does not start with a number is added to the current candidate
--   -- 3. candidates that do not start with a number are eliminated
--   -- ien index: nrs donot start at first column ... so this will fail
--   local idx = { '' }
--
--   for _, line in ipairs(lines) do
--     if string.match(line, '^%s*%d+%s') then
--       -- format current entry, then start new entry
--       idx[#idx] = H.idx_entry_build(topic, idx[#idx])
--       idx[#idx + 1] = line
--     elseif string.match(line, '^%s+') then
--       -- accumulate in new candidate
--       -- TODO: do we actually need to check for starting whitespace?
--       idx[#idx] = idx[#idx] .. ' ' .. vim.trim(line)
--     end
--   end
--
--   -- also format last accumulated candidate (possibly deleting it)
--   idx[#idx] = H.idx_entry_build(topic, idx[#idx])
--   vim.notify('index ' .. topic .. ' has ' .. #idx .. ' entries', vim.log.levels.WARN)
--   return idx
-- end

-- function H.idx_parse(index)
--   -- index is list of formatted index lines (stream|nr|text)
--   -- return list of { {topic, id, text}, .. }
--   local idx = {}
--   for _, line in ipairs(index) do
--     local topic, id, text = H.idx_entry_parse(line)
--     if topic and id and text then
--       idx[#idx + 1] = { topic, id, text }
--     else
--       vim.notify('[error] ill-formed index line ' .. line, vim.log.levels.WARN)
--     end
--   end
--   return idx
-- end

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

-- function H.to_url(topic, id)
--   -- return url for an item or index
--   local base = 'https://www.rfc-editor.org'
--   topic = string.lower(topic)
--
--   if not H.valid[topic] then
--     error('topic must one of: rfc, bcp, std, fyi or ien')
--   end
--
--   if id == 'index' then
--     return string.format('%s/%s/%s-%s.txt', base, topic, topic, id)
--   end
--
--   id = tonumber(id)
--   if id ~= nil then
--     -- removes leading zero's, so 0009 -> 9
--     return string.format('%s/%s/%s%d.txt', base, topic, topic, id)
--   end
--
--   error('id must be one of: "index" or a number')
-- end

--[[ H mod new]]
-- helper functions for small tasks
-- note that caller is assumed to check validity of args and values
-- so here we `assert` and possibly fail hard

H.valid = { rfc = true, bcp = true, std = true, fyi = true, ien = true }
H.top = 'ietf.org'
H.sep = '│'

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

--- fetch an ietf document, returns (possibly empty) list of lines
function H.fetch(topic, id)
  -- return a, possibly empty, list of lines
  local url = H.url(topic, id)
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

--- find root dir or use cfg.top, fallback to stdpath data dir
function H.dir(spec)
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
function H.fname(stream, id, ext)
  assert(H.valid[stream])

  -- return full file path for (stream, id) or nil
  id = id or 'index'
  ext = ext or 'txt'
  local fdir, fname
  local cfg = M.config
  local top = M.config.top or H.top

  if id == 'index' then
    -- it's an document index
    fdir = cfg.cache
    fname = vim.fs.joinpath(fdir, top, string.format('%s-index.%s', stream, ext))
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
  fname = vim.fs.joinpath(fdir, top, stream, string.format('%s%d.%s', stream, id, ext))

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

function H.symbol(exists)
  -- local symbol = { '', '', ☻ , ☹ ,  🗎🗋}
  if exists then
    return '🗎'
  else
    return '🗋'
  end
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

--[[ INDEX ]]
-- functions that work with the indices of streams of ietf documents

local Idx = {}

--- retrieve an index from the ietf
function Idx.curl(stream)
  -- returns, possibly empty, list: { {stream, nr, text}, .. }
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

  -- parse assembled line into {stream, id, text}
  local parse = function(line)
    -- return a parsed accumulated entry line (if any) or nil upon failure
    local nr, title = string.match(line, '^(%d+)%s+(.*)')
    nr = tonumber(nr) -- eleminate any leading zero's
    if nr ~= nil then
      return { stream, nr, title }
    end
    return nil -- so it actually won't add the entry
  end

  -- assemble and parse lines
  local idx = {} -- parsed content { {s, n, t}, ... }
  local acc = '' -- start of accumulated line
  local max = stream == 'ien' and 3 or 1
  for _, line in ipairs(rv.lines) do
    local start = string.match(line, '^(%s*)%d+%s+%S')
    if start and #start < max then
      -- starter line: parse current, start new
      vim.print(vim.inspect({ #start, max, line }))
      idx[#idx + 1] = parse(acc)
      acc = vim.trim(line) -- trim leading ws(!) for parse()
    elseif #acc > 0 and string.match(line, '^%s+%S') then
      -- continuation line: accumulate
      acc = acc .. ' ' .. vim.trim(line)
    else
      -- neither a starter, nor continuation: parse current, restart
      idx[#idx + 1] = parse(acc)
      acc = ''
    end
  end
  -- don't forget the last entry (if any)
  idx[#idx + 1] = parse(acc)

  return idx -- { {stream, nr, title }, .. }
end

--- retrieve a stream's index from disk or ietf
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

--- build an index for 1 or more types of streams
function Idx.index(streams)
  -- returns { {stream<1>, nr, title}, ... {stream<n>, nr, title} }
  streams = streams or { 'rfc' }
  streams = type(streams) == 'string' and { streams } or streams
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

--[[ ITEMs ]]

--- state and functions that work with picker items
local Itm = { list = {} }

--- returns title, ft, lines for use in a preview
--- (in case no text file is present to be previewd)
function Itm.preview(item)
  -- will be viewed with filetype `markdown`
  local title = tostring(item.title)
  local ft = 'markdown'
  local ext = item.tags.formats and item.tags.formats[1] or 'txt'
  local fmt2cols = '   %-15s%s'
  local f = string.format
  local authors = #item.tags.authors > 0 and table.concat(item.tags.authors, ', ')
  local formats = #item.tags.formats > 0 and table.concat(item.tags.formats, ', ')
  local obsoletes = item.tags.obsoletes

  local lines = {
    '',
    f('# %s', string.upper(item.name)),
    '',
    '',
    f('## %s', item.text),
    '',
    f(fmt2cols, 'AUTHORS', authors or 'n/a'),
    f(fmt2cols, 'STATUS', item.tags.status or 'n/a'),
    f(fmt2cols, 'DATE', item.tags.date or 'n/a'),
    '',
    f(fmt2cols, 'STREAM', item.stream),
    f(fmt2cols, 'FORMATS', formats or 'n/a'),
    f(fmt2cols, 'DOI', item.tags.doi or 'n/a'),
    '',
    '### TAGS',
    '',
    f(fmt2cols, 'ALSO', item.tags.also or '-'),
    f(fmt2cols, 'OBSOLETES', item.tags.obsoletes or '-'),
    f(fmt2cols, 'OBSOLETED by', item.tags.obsoleted_by or '-'),
    f(fmt2cols, 'UPDATES', item.tags.updates or '-'),
    f(fmt2cols, 'UPDATED by', item.tags.updated_by or '-'),
    '',
    '### URI',
    '',
    f(fmt2cols, 'PATH', vim.fn.fnamemodify(item.file, ':p:~:.')),
    f(fmt2cols, 'URL', H.url(item.stream, item.id, ext)),
  }

  return title, ft, lines
end

--- Builds self.list of picker items, from 1 or more streams; returns #items
function Itm:from(streams)
  local index = Idx.index(streams) -- { {stream, nr, text}, .. }

  if #index == 0 then
    vim.notify('[warn] found 0 items for streams: ' .. table.concat(streams, ', '), vim.log.levels.WARN)
    return 0 -- zero entries
  end

  self.list = {}
  for idx, entry in ipairs(index) do
    table.insert(self.list, Itm.new(idx, entry))
  end
  return #self.list -- num of entries in self.list
end

--- create a new picker item for given (idx, {stream, id, text})
function Itm.new(idx, entry)
  local item = nil -- returned if entry is malformed
  local stream, id, text = unpack(entry)
  if stream and id and text then
    local title, tags = Itm.parse(text)
    local ext = tags.formats and tags.formats[1] or 'txt'
    local fname = H.fname(stream, id, ext)
    local exists = fname and vim.fn.filereadable(fname) == 1

    item = {
      idx = idx,
      score = idx,
      text = title,
      name = string.format('%s%d', stream, id),
      file = fname, -- used for previewing file if present
      title = string.format('%s%s', stream, id), -- used by previewer

      -- extra, used by our picker preview to construct viewable content
      -- in case the file does not exist on disk.
      exists = exists,
      tags = tags,
      stream = stream,
      id = id,
      symbol = H.symbol(exists),
    }
  end
  return item -- if nil, won't get added to the list
end

--- extracs known (_tags_) from document title
function Itm.parse(text)
  -- take out all (tag: stuff) and (word word words) parts
  -- (Status: _) (Format: _) (DOI: _) (Obsoletes _) (Obsoleted by _) (Updates _) (Updated by _)
  local tags = { format = '' }
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

  -- extract (<wanted> ... )-parts
  for part in string.gmatch(text, '%(([^)]+)%)') do
    local prepped = string.gsub(part, '%s+by', '_by', 1):gsub(':', '', 1)
    local k, v = string.match(prepped, '^([^%s]+)%s+(.*)$')
    if k and v and wanted[k:lower()] then
      tags[k:lower()] = v:gsub('%s+', ''):lower()
      -- remove matched ()-text, including a ws prefix if possible
      text = string.gsub(text, '%s?%(' .. part .. '%)', '', 1)
    end
  end

  -- fix format tags
  -- order is important: first item in the list will be used to open it
  local known = { 'txt', 'html', 'pdf', 'xml' } -- json is not a pub format
  local formats = tags['format'] or ''
  local seen = {}
  for _, fmt in ipairs(known) do
    if string.match(formats, fmt) then
      seen[#seen + 1] = fmt
    end
  end
  tags['format'] = nil
  tags['formats'] = seen

  -- TODO: switch to vim.re/vim.regex or vim.lpeg
  -- extract dates like: Month<ws>YEAR (4 digits) (covers rfc,bcp and std)
  local date = text:match('%s%u%l+%s-%d%d%d%d%.?')
  if date then
    tags['date'] = vim.trim(date):gsub('%.$', '', 1) -- TODO: keep the trailing dot?
    text = string.gsub(text, date, '', 1)
  end

  -- extract authors
  local authors = text:match('%s%u%.%u?%.?%s.*%.')
  if authors and #authors > 0 then
    text = text:gsub(authors, '', 1)
    authors = vim.split(authors:gsub('^%s', '', 1):gsub('%.+$', '', 1), ', *')
  end
  tags['authors'] = authors or {}

  return text, tags
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
  local topdir = H.dir(M.config.data)
  snacks.picker.files({ hidden = true, cwd = topdir })
end

function M.grep()
  local topdir = H.dir(M.config.data)
  snacks.picker.grep({ hidden = true, cwd = topdir })
end

function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts)

  return M
end

function M.search(streams)
  -- search the stream(s) index/indices
  -- TODO:
  -- [x] arg maybe streams, e.g. {'rfc', 'bcp', 'std'} and concat the index lists of named topics
  -- [x] use H.sep instead of magical '|' char
  -- [x] idx_entry_build(topic, line)  & idx_entry_parse(entry) -> topic, id
  -- Use the source Luke!
  -- * `:!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/preview.lua`
  -- *  ``:!open https://github.com/folke/todo-comments.nvim/blob/main/lua/todo-comments/search.lua`
  -- * `:!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/preview.lua`

  Itm:from(streams)
  local name_fmt = '%-' .. (3 + #(tostring(#Itm.list))) .. 's'
  vim.print(vim.inspect({ #Itm.list, name_fmt }))

  return snacks.picker({
    items = Itm.list,
    -- gets called as preview function, perhaps see snacks.picker.prewiew for
    -- example code?
    preview = function(ctx)
      if ctx.item.exists then
        -- defer to regular previewing in nvim
        -- TODO: what if it's a pdf-file?
        snacks.picker.preview.file(ctx)
      elseif ctx.item.missing then
        -- we've seen it before, use previously assembled info
        -- we donot use ctx.item.preview={ft=.., text=".."} since text must be split
        -- each time its the current item in the list
        -- see snacks.picker.core.preview for funcs below ..
        ctx.preview:reset()
        ctx.preview:set_lines(ctx.item.missing.lines)
        ctx.preview:set_title(ctx.item.missing.title)
        ctx.preview:highlight({ ft = ctx.item.missing.ft })
      else
        -- create table `missing` to use for previewing
        local title, ft, lines = Itm.preview(ctx.item)
        ctx.preview:reset()
        ctx.preview:set_lines(lines)
        ctx.preview:set_title(title)
        ctx.preview:highlight({ ft = ft })
        -- create table for next time this item needs to be previewed
        ctx.item.missing = { title = title, ft = ft, lines = lines }
      end
    end,
    -- see `!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/config/defaults.lua`
    -- around Line 200, win = { input = { keys = {..}}, list = { keys = {..}}}
    win = {
      list = {
        -- this is the window where list being search/filtered is displayed
        -- ('/' toggle focus between list/input window)
        -- <c-g/G> originally toggles live_grep which is not supported in
        -- search anyway.  Hmm. can't override it here.
        keys = {
          -- <enter> is confirm & act on selection
          -- [<TAB>] is select_and_next, will select an item (input/list win)
          -- <c-a> will (de)select all
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
      local hl_item = (item.exists and 'SnacksPickerGitStatusAdded') or 'SnacksPickerGitStatusUntracked'
      local ret = {}
      ret[#ret + 1] = { item.symbol, hl_item }
      ret[#ret + 1] = { ' ' .. H.sep, 'SnacksWinKeySep' }
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
        local lines = H.fetch(item.stream, item.id)
        if #lines > 0 then
          H.save(item.stream, item.id, lines)
          vim.cmd('edit ' .. item.file)
        end
      else
        vim.cmd('edit ' .. item.file)
      end
    end,
  })
end

function M.test(streams)
  -- sanitize input
  streams = streams or { 'rfc' }
  streams = type(streams) == 'string' and { streams } or streams

  local count = Itm:from(streams)
  vim.print('Got ' .. count .. 'entries for stream(s): ' .. table.concat(streams, ','))
  for idx, item in ipairs(Itm.list) do
    vim.print({ idx, vim.inspect(item) })
  end
end

return M
