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

--[[ TYPES ]]

---@alias stream "rfc" | "bcp" | "std" | "fyi" | "ien"
---@alias entry { [1]: stream, [2]: integer, [3]: string}
---@alias index entry[]

local M = {} -- TODO: review how/why H.methods require M access
-- if not needed anymore, it can move to the [[ MODULE ]] section

--[[ DEPENDENCIES ]]

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

--[[ HELPERS ]]
-- H.methods assume caller already checked validity of arguments supplied
-- so they simply `assert` and possibly fail hard

local H = {
  valid = { rfc = true, bcp = true, std = true, fyi = true, ien = true },
  top = 'ietf.org',
  sep = '│',
}

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
---@param stream stream
function H.fetch(stream, id)
  -- return a, possibly empty, list of lines
  local url = H.url(stream, id)
  local rv = plenary.curl.get({ url = url, accept = 'plain/text' })

  if rv and rv.status == 200 then
    -- no newline's for buf set lines, no formfeed for snacks preview
    local lines = vim.split(rv.body, '[\r\n\f]')
    vim.notify('downloaded ' .. stream .. ' (' .. #lines .. 'lines)')
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

-- returns modeline string if possible, nil otherwise
function H.modeline(spec)
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

-- save to disk, creating directory as needed
function H.save(stream, id, lines)
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

--- returns a file's ttl, exists?
---@param fname string
function H.ttl(fname)
  -- remaining TTL [seconds], stream-file age [seconds]
  local ttl = M.config.ttl or 0
  local ftime = vim.fn.getftime(fname) -- if file unreadable, then ftime = -1
  return ttl + ftime - vim.fn.localtime(), ftime ~= -1
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

---@class Index
---@field curl fun(stream: stream): index
---@field get fun(self: Index, stream: stream): Index
---@field index fun(self: Index, streams: stream[]): Index
local Idx = {}

-- retrieves (and caches) an index for the given `stream` from the ietf
-- returns a list: { {stream, id, text}, .. } or nil on failure
---@return index | nil
function Idx.curl(stream)
  -- retrieve raw content from the ietf
  local url = H.url(stream, 'index')
  local rv = H.curl(url)
  if rv.status ~= 200 then
    vim.notify('[warn] download failed: [' .. rv.status .. '] ' .. url, vim.log.levels.ERROR)
    return nil
  end

  -- parse assembled line into {stream, id, text}
  ---@param line string
  ---@return entry | nil
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
  local acc = '' -- accumulated sofar
  local max = stream == 'ien' and 3 or 1 -- allow for leading ws in ien index
  for _, line in ipairs(rv.lines) do
    local start = string.match(line, '^(%s*)%d+%s+%S')
    if start and #start < max then
      -- starter line: parse current, start new
      idx[#idx + 1] = parse(acc)
      acc = vim.trim(line) -- trim leading ws(!) for parse()
    elseif #acc > 0 and string.match(line, '^%s+%S') then
      -- continuation line: accumulate
      acc = acc .. ' ' .. vim.trim(line)
    elseif #acc > 0 then
      -- neither a starter, nor continuation: parse current, restart
      idx[#idx + 1] = parse(acc)
      acc = ''
    end
  end
  -- don't forget the last entry
  idx[#idx + 1] = parse(acc)

  if #idx > 0 then
    -- cache the parsed result
    local lines = {}
    for _, entry in ipairs(idx) do
      lines[#lines + 1] = table.concat(entry, H.sep)
    end
    H.save(stream, 'index', lines)
  else
    return nil -- fail
  end

  return idx -- { {stream, nr, title }, .. }
end

-- adds an index (local/remote) for a stream (possibly update cache)
---@param self Index
---@param stream stream
---@return Index
function Idx:get(stream)
  -- get a single stream, either from disk or from ietf
  -- NOTE: we do not check if stream is already present in self
  local idx = {} ---@type index
  local fname = H.fname(stream, 'index')
  local ttl = H.ttl(fname)

  ---@return index | nil
  local readfile = function()
    -- try to read index from local file
    local rv
    ok, rv = pcall(vim.fn.readfile, fname)
    if ok and #rv > 0 then
      for _, line in ipairs(rv) do
        idx[#idx + 1] = vim.split(line, H.sep)
      end
    else
      return nil
    end
    return idx
  end

  if ttl < 1 then
    idx = Idx.curl(stream) or readfile()
  else
    idx = readfile() or Idx.curl(stream)
  end

  if #idx < 1 then
    vim.notify('[warn] no index available for ' .. stream, vim.log.levels.WARN)
  end

  for _, entry in ipairs(idx) do
    table.insert(self, entry)
  end

  return self
end

--- build an index for 1 or more types of streams
---@param self Index
---@param streams stream[]
---@return entry[]
function Idx:from(streams)
  -- clear index
  local cnt = #Idx
  for i = 0, cnt do
    Idx[i] = nil
  end

  -- refill
  streams = streams or { 'rfc' }
  streams = type(streams) == 'string' and { streams } or streams
  for _, stream in ipairs(streams) do
    assert(H.valid[stream])
    Idx:get(stream)
  end
  return self
end

--[[ ITEM ]]
--- state and functions that work with picker items

---@class Items
---@field preview fun(item: table): title: string, ft: string, lines: string[]
---@field from fun(self: Items, streams: stream[]): Items
---@field new fun(idx: integer, entry: entry): item: table
---@field parse fun(text: string): text: string, tags:table
local Itms = { list = {} }

--- returns `title`, `ft`, `lines` for use in a preview
--- (used when no local file is present to be previewd)
---@param item table An item of the picker result list
---@return string title The title for an item
---@return string ft The filetype to use when previewing
---@return table lines The lines to display when previewing
function Itms.preview(item)
  local title = tostring(item.title)
  local ft = 'markdown'
  local fmt2cols = '   %-15s%s'
  local f = string.format
  -- REVIEW: tags are not consistent: plurals should always be lists of strings?
  local ext = item.tags.formats and item.tags.formats[1] or 'txt'
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
    f(fmt2cols, 'AUTHORS', authors or '-'),
    f(fmt2cols, 'STATUS', item.tags.status or '-'),
    f(fmt2cols, 'DATE', item.tags.date or '-'),
    '',
    f(fmt2cols, 'STREAM', item.stream),
    f(fmt2cols, 'FORMATS', formats or '-'),
    f(fmt2cols, 'DOI', item.tags.doi or '-'),
    '',
    '',
    '### TAGS',
    '',
    f(fmt2cols, 'ALSO', item.tags.also or '-'),
    f(fmt2cols, 'OBSOLETES', item.tags.obsoletes or '-'),
    f(fmt2cols, 'OBSOLETED by', item.tags.obsoleted_by or '-'),
    f(fmt2cols, 'UPDATES', item.tags.updates or '-'),
    f(fmt2cols, 'UPDATED by', item.tags.updated_by or '-'),
    '',
    '',
    '### URI',
    '',
    f(fmt2cols, 'PATH', vim.fn.fnamemodify(item.file, ':p:~:.')),
    f(fmt2cols, 'URL', H.url(item.stream, item.id, ext)),
  }

  return title, ft, lines
end

--- Builds self.list of picker items, from 1 or more streams; returns #items
---@param self Items
---@param streams stream[]
---@return Items | nil
function Itms:from(streams)
  -- clear self first
  -- TODO: may check if clear/refill is needed, if not use as-is?
  -- that prevents reading from disk: e.g. ttl is ok
  local cnt = #Itms
  for i = 0, cnt do
    Itms[i] = nil
  end

  -- refill
  Idx:from(streams) -- { {stream, nr, text}, .. }

  if #Idx == 0 then
    return nil
  end

  for idx, entry in ipairs(Idx) do
    table.insert(self, Itms.new(idx, entry))
  end
  return self
end

--- create a new picker item for given (idx, {stream, id, text})
---@param idx integer
---@param entry entry
---@return table | nil
function Itms.new(idx, entry)
  local item = nil -- returned if entry is malformed
  local stream, id, text = unpack(entry)
  if stream and id and text then
    local title, tags = Itms.parse(text)
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

--- extracts known `tags` from an entry's `text`
---@param text string -- A full, assembled, index line
---@return string text Remaining text after removings tags
---@return table tags Known tags removed from text
function Itms.parse(text)
  -- take out all (word <stuff>) for known words
  -- (Status: _), ..., (Obsoletes _) (Obsoleted by _), ...
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

  -- extract dates
  -- TODO: switch to vim.re/vim.regex or vim.lpeg? ien/fyi not consistent
  local date = text:match('%s%u%l+%s-%d%d%d%d%.?') -- Month\sYEAR
  if date then
    tags['date'] = vim.trim(date):gsub('%.$', '', 1)
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
  ttl = 60, -- time-to-live [second], before downloading again
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

  vim.print(vim.inspect({ 'streams', streams, '#Idx', #Idx, '#Itms', #Itms }))
  Itms:from(streams)
  local name_fmt = '%-' .. (3 + #(tostring(#Itms.list))) .. 's'
  vim.print(vim.inspect({ 'streams', streams, '#Idx', #Idx, '#Itms', #Itms }))

  return snacks.picker({
    items = Itms,
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
        local title, ft, lines = Itms.preview(ctx.item)
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
      -- TODO: retrieve txt items, use vim.ui.open for (remote) formats other
      -- than txt.  Can we curl pdf's ?
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

  local count = Itms:from(streams)
  vim.print('Got ' .. count .. 'entries for stream(s): ' .. table.concat(streams, ','))
  for idx, item in ipairs(Itms.list) do
    vim.print({ idx, vim.inspect(item) })
  end
end

return M
