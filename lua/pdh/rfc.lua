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
- [ ] How to handle the (possibly) formats:
      - default to first Itms.FORMATS, if available then no questions asked
      - if not available, use the next one
      - preview: if txt is available, use that, otherwise preview the item
      - open: use first format available, txt opened in nvim, rest is !open'd
- [ ] formats other than TXT are redirected to browser w/ a URL (.pdf, .html etc..) or the info page
      e.g. https://www.editor-rfc.org/info/rfc8  (no extension)
- [ ] info page the default when choosing to browse for an rfc, rather than downloading it?
- [ ] no local file, just show the item without the error msg.  Howto avoid that error?
- [ ] when download fails, flash a warning and do not create a local file with just a modeline.
- [ ] how to handle icons properly?

NOTE:
- :Show lua =require'snacks'.picker.lines() -> new tab with picker return value printed for inspection
- finder:
- matcher:
  * with field:pattern, this matches against item.field=..., so item.author=concat(tags.authors)
    - a nested field (like tags.date won't be used as such a match)
A picker normally searches only in item.text for a match, not in the results display list lines!
-
--]]

--[[ TYPES ]]

---@alias stream "rfc" | "bcp" | "std" | "fyi" | "ien"
---@alias entry { [1]: stream, [2]: integer, [3]: string}
---@alias index entry[]

local M = {} -- TODO: review how/why H.methods require M access
-- if not needed anymore, it can move to the [[ MODULE ]] section

--[[ DEPENDENCIES ]]
local function dependency(name)
  -- so we avoid introducing ok as a script wide variable
  local ok, var = pcall(require, name)
  if not ok then
    vim.notify('[error] missing dependency: ' .. name, vim.log.levels.ERROR)
    return
  end
  return var
end

-- check all dependencies before bailing (if applicable)
local plenary = dependency('plenary')
local snacks = dependency('snacks')
-- if one of the dependencies are not there, bail
if not plenary then return end
if not snacks then return end

--[[ HELPERS ]]
-- H.methods assume caller already checked validity of arguments supplied
-- so they simply `assert` and possibly fail hard

local H = {
  -- valid values for stream
  valid = { rfc = true, bcp = true, std = true, fyi = true, ien = true },
  top = 'ietf.org', -- subdir under topdir for ietf documents
  sep = '│', -- separator for local index lines: stream|id|text
}

--- fetch an ietf document, returns (possibly empty) list of lines
---@param stream stream
function H.fetch(stream, id)
  -- return a, possibly empty, list of lines
  -- TODO: use pcall so we do not error out needlessly
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

  if path == nil or vim.fn.filereadable(path) == 0 then path = vim.fn.stdpath('data') end

  -- path = (path and vim.fn.filereadable(path)) or vim.fn.stdpath('data')
  return vim.fs.joinpath(path, top)
end

---@param stream stream
---@param id string|number|nil
---@param ext string
function H.fname(stream, id, ext)
  -- return full file path for (stream, id) or nil
  -- keep stream and ext lower case at all times
  id = id or 'index'
  ext = ext and ext:lower() or 'txt'
  stream = stream and stream:lower()
  local fdir, fname
  local cfg = M.config
  local top = M.config.top or H.top

  if id == 'index' then
    -- it's an document index, ext is always txt
    fdir = cfg.cache
    fname = vim.fs.joinpath(fdir, top, string.format('%s-index.%s', stream, 'txt'))
    return vim.fs.normalize(fname)
  end

  -- id is an ietf document number
  id = tonumber(id) -- eliminate leading zero's (if any)
  assert(id)

  -- find fdir based on markers
  if type(cfg.data) == 'table' then fdir = vim.fs.root(0, cfg.data) end

  fdir = fdir or cfg.data or vim.fn.stdpath('data')
  fname = vim.fs.joinpath(fdir, top, stream, string.format('%s%d.%s', stream, id, ext))

  return vim.fs.normalize(fname)
end

-- returns a modeline string if possible, nil otherwise
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
    if #opts > 0 then return string.format('/* vim: set%s: */', opts) end
  end

  return nil -- do not add modeline
end

-- save to disk, creating directory as needed
function H.save(stream, id, lines)
  local fname = H.fname(stream, id, 'txt')

  if fname == nil then return fname end

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

function H.url(stream, id, ext)
  -- returns url for stream document or its index

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
---@field curl fun(stream: stream): index Retrieve (and cache) an index from the ietf
---@field get fun(self: Index, stream: stream): Index Add an index to Idx
---@field index fun(self: Index, streams: stream[]): Index Add one or more indices to Idx
local Idx = {}

-- retrieves (and caches) an index for the given `stream` from the ietf
-- returns a list: { {stream, id, text}, .. } or nil on failure
---@return index | nil
function Idx.curl(stream)
  -- retrieve raw content from the ietf
  local url = H.url(stream, 'index')

  -- retrieve index from the ietf
  local lines = {}
  local ok, rv = pcall(plenary.curl.get, { url = url, accept = 'plain/text' })

  if ok and rv and rv.status == 200 then
    -- no newline's for buf set lines, no formfeed for snacks preview
    lines = vim.split(rv.body, '[\r\n\f]')
  else
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
    if nr ~= nil then return { stream, nr, title } end
    return nil -- so it actually won't add the entry
  end

  -- assemble and parse lines
  local idx = {} -- parsed content { {s, n, t}, ... }
  local acc = '' -- accumulated sofar
  local max = stream == 'ien' and 3 or 1 -- allow for leading ws in ien index
  for _, line in ipairs(lines) do
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
    lines = {}
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
  local fname = H.fname(stream, 'index', 'txt')
  local ftime = vim.fn.getftime(fname) -- if file unreadable, then ftime = -1
  local ttl = (M.config.ttl or 0) + ftime - vim.fn.localtime()

  ---@return index | nil
  local readfile = function()
    -- try to read index from local file
    local ok, rv = pcall(vim.fn.readfile, fname)
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

  if #idx < 1 then vim.notify('[warn] no index available for ' .. stream, vim.log.levels.WARN) end

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
  streams = vim.tbl_map(string.lower, streams) -- stream names always lowercase
  for _, stream in ipairs(streams) do
    assert(H.valid[stream])
    Idx:get(stream)
  end
  return self
end

--[[ ITEM ]]
--- state and functions that work with picker items
--- TODO:
--- [ ] Itms.fname() -> fname (first existing or possible), exists
---     to be used for preferred download/open and exists for Icon in result list
--- [ ] confirm ext if multiple are possible before download
--- [ ] preview should not defer to picker, do it ourself
---     that way we can curl to output file & preview older rfc's with a
---     formfeed character (picker would warn of a binary file)

---@class Items
---@field preview fun(item: table): title: string, ft: string, lines: string[]
---@field from fun(self: Items, streams: stream[]): Items
---@field new fun(idx: integer, entry: entry): item: table
---@field parse fun(text: string): text: string, tags:table
local Itms = {
  ICONS = {
    -- NOTE: add a space after the icon (it is used as-is here)
    [false] = ' ',
    [true] = ' ',

    -- REVIEW: add icons for publication formats here? Not used (yet)
    txt = ' ', -- text
  },

  FORMATS = { -- publication formats, order is to check for presence or download
    'txt',
    'html',
    'xml',
    'pdf',
  },
}

--- Builds self.list of picker items, from 1 or more streams; returns #items
---@param self Items
---@param streams stream[]
---@return Items | nil
function Itms:from(streams)
  -- clear self first, TODO: only needed if streams altered or TTL's expired
  local cnt = #Itms
  for i = 0, cnt do
    Itms[i] = nil
  end

  -- refill
  Idx:from(streams) -- { {stream, nr, text}, .. }

  if #Idx == 0 then return nil end

  for idx, entry in ipairs(Idx) do
    table.insert(self, Itms.new(idx, entry))
  end
  return self
end

---@param item table
---@return table[] parts of the line to display in results list window for `item`
function Itms.format(item)
  -- format an item to display in picker list
  -- `!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/format.lua`
  local exists = item.file and true or false -- (vim.fn.filereadable(item.file) == 1)
  local icon = Itms.ICONS[exists]
  local hl_item = (exists and 'SnacksPickerGitStatusAdded') or 'SnacksPickerGitStatusUntracked'
  local name = ('%-' .. (3 + #(tostring(#Itms))) .. 's'):format(item.name)
  local ret = {
    { icon, hl_item },
    { H.sep, 'SnacksWinKeySep' },
    { name, hl_item },
    { H.sep, 'SnacksWinKeySep' },
    { item.text, '' },
    { ' ' .. item.date, 'SnacksWinKeySep' },
  }

  return ret
end

--- create a new picker item for given (idx, {stream, id, text})
---@param idx integer
---@param entry entry
---@return table | nil item fields parsed from an index entry's text or nil
function Itms.new(idx, entry)
  local item = nil -- returned if entry is malformed
  local stream, id, text = unpack(entry)
  if stream and id and text then
    item = {
      idx = idx,
      score = idx,
      -- file = <to be updated later>, if set, item has local file
      text = text,
      title = string.format('%s%s', stream, id):upper(), -- title of preview window

      -- extra fields to search on
      name = string.format('%s%d', stream, id):upper(),
      stream = stream:lower(),
      id = id,
    }

    -- update fields in item
    Itms.set_tags(item)
    Itms.set_file(item)
  end

  return item -- if nil, won't get added to the list
end

--- Sets item.file to the first filename on disk (if any) in order of Itms.FORMATS
---@param item table
---@return table item sets item.file is either the first filename found or nil (missing)
function Itms.set_file(item)
  item.file = nil -- nothing found yet
  for _, ext in ipairs(Itms.FORMATS) do
    local fname = H.fname(item.stream, item.id, ext)
    if fname and vim.fn.filereadable(fname) == 1 then
      item.file = fname
      break
    end
  end
  return item
end

--- extracts known `tags` from an entry's `text` and adds them as named fields
---@param item table
---@return table item with parsed tags added as extra fields
function Itms.set_tags(item)
  -- take out all (word <stuff>) for known words
  -- (Status: _), ..., (Obsoletes _) (Obsoleted by _), ...
  local tags = {
    -- ensure these tags are present with a default value
    obsoletes = '-',
    obsoleted_by = '-',
    updates = '-',
    updated_by = '-',
    also = '-',
    status = '-',
    format = '', -- empty string means no format(s) listed/found
    doi = '-',
    -- these two are not `()`-constructs
    authors = '-',
    date = '-',
  }

  -- ensure all known tags, with their defaults, are present in item
  for k, v in pairs(tags) do
    item[k] = v
  end

  -- extract (<tag> ... )-constructs
  for part in string.gmatch(item.text, '%(([^)]+)%)') do
    -- lowercase so we can match on keys in tags
    local prepped = part:lower():gsub('%s+by', '_by', 1):gsub(':', '', 1)
    local k, v = string.match(prepped, '^([^%s]+)%s+(.*)$')
    if k and v and tags[k] then
      item[k] = v -- v = v:gsub('%s+', '')
      -- `part` yielded a tagged value, so remove its first occurrence
      item.text = string.gsub(item.text, '%s?%(' .. part .. '%)', '', 1)
    end
  end

  -- fix item.formats value
  -- `known` order is important: first item is used to download/open it
  -- local known = { 'txt', 'html', 'pdf', 'xml' } -- TODO: make this an Itms.FORMAT constant list
  local seen = {}
  for _, fmt in ipairs(Itms.FORMATS) do
    if item.format:match(fmt) then seen[#seen + 1] = fmt end
  end
  if #seen > 0 then
    -- keep the default '-' if no formats were found
    item.format = table.concat(seen, ', ')
  end

  -- extract date
  -- TODO:
  -- [ ] switch to vim.re/vim.regex or vim.lpeg? ien/fyi not consistent
  -- [x] Date is <ws>Mon<ws>YYYY<dot>, e.g. May 1986.
  local date = item.text:match('%s%u%l%l%l-%s-%d%d%d%d%.?')
  if date then
    item.date = vim.trim(date):gsub('%.$', '')
    item.text = string.gsub(item.text, date, '', 1)
  end

  -- extract authors
  local authors = item.text:match('%s%u%.%u?%.?%s.*%.')
  if authors and #authors > 0 then
    item.text = item.text:gsub(authors, '', 1)
    item.authors = authors:gsub('^%s', ''):gsub('%.+$', ''):gsub('%s%s+', ' ')
  end

  return item
end

--- returns `title`, `ft`, `lines` for use in a preview
--- (used when no local file is present to be previewd)
---@param item table An item of the picker result list
---@return string title The title for an item
---@return string ft The filetype to use when previewing
---@return table lines The lines to display when previewing
function Itms.preview(item)
  -- called when item not locally available
  local title = tostring(item.title)
  local ft = 'markdown'
  -- local cache = vim.fs.joinpath(vim.fn.fnamemodify(M.config.cache, ':p:~:.'), M.config.top, '/')
  -- local data = vim.fs.joinpath(vim.fn.fnamemodify(M.config.data, ':p:~:.'), M.config.top, '/')
  local cache = vim.fs.joinpath(M.config.cache, M.config.top, '/')
  local data = vim.fs.joinpath(M.config.data, M.config.top, '/')
  local file = item.file or '*n/a*'
  local fmt2cols = '   %-15s%s'
  local fmt2path = '   %-15s%s' -- prevent strikethrough's use `%s` (if using ~ in path)
  local f = string.format
  local url
  local ext = vim.split(item.format, ',%s*')[1] -- for (possible) url
  if #ext == 0 then
    url = H.url(item.stream, item.id, 'txt') .. ' (*maybe*)'
  else
    url = H.url(item.stream, item.id, ext)
  end

  local lines = {
    '',
    f('# %s', item.name),
    '',
    '',
    f('## %s', item.text),
    '',
    f(fmt2cols, 'AUTHORS', item.authors),
    f(fmt2cols, 'STATUS', item.status:upper()),
    f(fmt2cols, 'DATE', item.date or '-'),
    '',
    f(fmt2cols, 'STREAM', item.stream:upper()),
    f(fmt2cols, 'FORMATS', item.format:upper()),
    f(fmt2cols, 'DOI', item.doi:upper()),
    '',
    '',
    '### TAGS',
    '',
    f(fmt2cols, 'ALSO', item.also:upper()),
    f(fmt2cols, 'OBSOLETES', item.obsoletes:upper()),
    f(fmt2cols, 'OBSOLETED by', item.obsoleted_by:upper()),
    f(fmt2cols, 'UPDATES', item.updates:upper()),
    f(fmt2cols, 'UPDATED by', item.updated_by:upper()),
    '',
    '',
    '### PATH',
    '',
    f(fmt2path, 'CACHE', cache),
    f(fmt2path, 'DATA', data),
    f(fmt2path, 'FILE', file),
    '',
    f(fmt2path, 'URL', url),
  }

  return title, ft, lines
end

--[[ Actions ]]
-- TODO:
-- [ ] configurable: select before download or default to 1st in line
-- [ ] configurable open action: select or edit, tabnew, !open as appropiate
--     sometimes you want to see the html/xml in neovim itself

local Act = {
  -- Act.actions.func defined later on, as per reference by win.list/input.keys
  actions = {},
  -- see `!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/config/defaults.lua`
  -- around Line 200, win = { input = { keys = {..}}, list = { keys = {..}}}
  win = {
    list = { -- the results list window
      keys = {
        ['<c-x>'] = { 'download', mode = { 'n', 'i' } },
        ['<c-m-x>'] = { 'download_selection', mode = { 'n', 'i' } },
      },
    },
    input = { -- the input window where search is typed
      keys = {
        ['<c-x>'] = { 'download', mode = { 'n', 'i' } },
        ['<c-m-x>'] = { 'download_selection', mode = { 'n', 'i' } },
        ['<c-y>'] = { 'echo', mode = { 'n', 'i' } },
      },
    },
  },
}

function Act.actions.download(picker, item)
  -- func names are tied to those mentioned in win.list/input key settings
  -- vim.print(vim.inspect({ 'download item', vim.inspect(item) }))
  -- vim.print(vim.inspect({ 'download selected is', picker.list.selected }))
end

function Act.actions.download_selection(picker, item)
  -- item is current item in the list
  -- picker.list.selected is list of selected items
  local x = picker.list.selected
  -- vim.print('selected ' .. #x .. ' items')
end

function Act.actions.echo(picker)
  -- vim.print('echo called')
  -- vim.print(vim.inspect({ 'echo', vim.inspect(picker) }))
end

function Act.confirm(picker, item)
  -- TODO:
  -- [ ] retrieve txt items, use vim.ui.open for (remote) formats other than txt.
  -- [ ] retrieve other formats through curl with --output <filename> option
  -- [ ] if fetching fails maybe put up selection to try another format?  Some
  --     ien files are only in pdf format (some are listed in the dir, but not
  --     downloadable for some reason, see ien7.pdf) IEN-index.txt has no info
  --     on the available formats .. so try as best as we can ..
  --     1. ien/ien<x>.txt | html | pdf
  --     2. ien/scanned/ien<x>.pdf or ien/scanned/ien<x>_reduced.pdf
  -- [ ] Apparently, in FORMATS HTML= bytes (w/o number) means 0 bytes, i.e.
  --     not available.
  picker:close()
  if vim.fn.filereadable(item.file) == 0 then
    local lines = H.fetch(item.stream, item.id)
    if #lines > 0 then
      H.save(item.stream, item.id, lines)
      -- vim.print(vim.inspect({ Itms[item.idx].name, item.name }))
      vim.cmd('edit ' .. item.file)
      vim.cmd('set ft=rfc')
      -- TODO: mark as downloaded and available here?
      -- [ ] this should be Itms.update(items), here called as Itms.update({item}).
    end
  else
    vim.cmd('edit ' .. item.file)
  end
end

function Act.preview(ctx)
  -- gets called to fill the preview window (if defined by user)
  -- see snacks.picker.core.preview for the preview funcs used below
  if ctx.item.file then
    -- defer to regular previewing in nvim for now
    -- TODO: what about 'binary' files (old rfc's or a pdf?)
    snacks.picker.preview.file(ctx)
  elseif ctx.item.missing then
    -- we've seen it before, use previously assembled info
    ctx.preview:reset()
    ctx.preview:set_lines(ctx.item.missing.lines)
    ctx.preview:set_title(ctx.item.missing.title)
    ctx.preview:highlight({ ft = ctx.item.missing.ft })
  else
    -- create table `missing` to use for previewing
    -- we do not set ctx.item.preview={ft=.., text=".."} since text must be split
    -- each time its the current item in the list
    local title, ft, lines = Itms.preview(ctx.item)
    ctx.preview:reset()
    ctx.preview:set_lines(lines)
    ctx.preview:set_title(title)
    ctx.preview:highlight({ ft = ft })
    -- create table for next time this item needs to be previewed
    ctx.item.missing = { title = title, ft = ft, lines = lines }
  end
end

--[[ Module ]]

M.config = {
  cache = vim.fn.stdpath('cache'), -- store indices only once
  data = vim.fn.stdpath('data'), -- path or markers
  top = 'ietf.org',
  ttl = 4 * 3600, -- time-to-live [second], before downloading again
  edit = 'tabedit ',
  symbol = 'smiley', -- others are document, whatever
  -- either set ft by vim.cmd after opening it, or add a modeline
  -- at the end of the file after downloading.
  filetype = {
    txt = 'rfc',
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
  -- TODO: expand stdpath for cache and data here once, reuse everywhere else
  M.config = vim.tbl_extend('force', M.config, opts)

  return M
end

function M.search(streams)
  -- search the stream(s) index/indices
  -- Use the source Luke!
  -- * `:!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/preview.lua`
  -- * `:!open https://github.com/folke/todo-comments.nvim/blob/main/lua/todo-comments/search.lua`
  -- * `:!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/preview.lua`

  -- TODO:
  -- [ ] if streams have not changed, donot load Itms again
  -- [ ] when resuming, check file status exists or not? Otherwise you download
  -- something, resume but it still shows as missing and marked for download.
  --
  Itms:from(streams)

  return snacks.picker({
    items = Itms,

    preview = Act.preview,
    actions = Act.actions,
    format = Itms.format,
    confirm = Act.confirm,
    win = Act.win,

    layout = {
      fullscreen = true,
    },
  })
end

function M.test() end

function M.select()
  local choices = Itms.FORMATS
  for idx, v in ipairs(choices) do
    v = v .. '|' .. ' ' .. H.fname('rfc', 123, v)
    choices[idx] = v
  end
  vim.ui.select(choices, {
    prompt = 'Select extension to download',
  }, function(choice)
    if choice == nil then choice = 'cancelled' end
    -- vim.print('your choice: ' .. choice)
  end)
end

function M.test_bit(stream, id)
  -- status could also be either nil or 1st ext found (txt, html etc..)
  -- or even nil vs { ext's }
  -- then there would be no need for bit op shenanigans
  -- snacks.input overrides vim.ui.input
  -- check out snacks.picker.select, snacks.util.spinner, plenary popup,
  -- plenary has a plenary.select
  stream = stream and stream:lower() or 'rfc'
  id = id or 1
  bit = require 'bit'

  local masks = {
    txt = 0x01,
    html = 0x02,
    pdf = 0x04,
    xml = 0x08,
  }

  local status = 0x00
  for ext, mask in pairs(masks) do
    local fname = H.fname(stream, id, ext)
    if vim.fn.filereadable(fname) == 1 then status = bit.bor(status, mask) end
  end

  local fext = {}
  for ext, mask in pairs(masks) do
    if bit.band(status, mask) ~= 0 then fext[#fext + 1] = ext end
  end

  -- vim.print(stream .. id .. ' available formats are: ' .. vim.inspect(fext))
end

vim.keymap.set('n', '<space>r', ":lua require'pdh.rfc'.reload()<cr>")

return M
