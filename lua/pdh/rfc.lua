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
- [x] How to handle the (possibly) formats:
      - default to first Itms.FORMATS, if available then no questions asked
      - if not available, use the next one
      - preview: if txt is available, use that, otherwise preview the item
      - open: use first format available, txt opened in nvim, rest is !open'd
- [x] formats other than TXT are redirected to browser w/ a URL (.pdf, .html etc..) or the info page
      e.g. https://www.editor-rfc.org/info/rfc8  (no extension)
- [c] info page the default when choosing to browse for an rfc, rather than downloading it?
- [x] no local file, just show the item without the error msg.  Howto avoid that error?
- [x] when download fails, flash a warning and do not create a local file with just a modeline.
- [x] how to handle icons properly?
- [ ] add item.errata if rfcnr is listed in `:!open https://www.rfc-editor.org/rfc/RFCs_for_errata.txt'
      * note: url is case sensitive!
      * errate itself is only available as a modified rfc<nr>.html, eg:
        `:!open https://www.rfc-editor.org/rfc/inline-errata/rfc1001.html`
        `:!open https://www.rfc-editor.org/rfc/inline-errata/`
      * maybe just add 'E' to open rfc/inline-errata/rfc<nr>.html (if any)
- references
  * `:!open https://www.rfc-editor.org/rfc/rfc-ref.txt`
  * `:!open https://www.rfc-editor.org/rfc/bcp-ref.txt`
  * `:!open https://www.rfc-editor.org/rfc/std-ref.txt` -> [std<nr>] lines with info url's of std and rfc's

- URLS

  * https://www.rfc-editor.org/
     `-rfc/                                                              : series kind
        |- rfc<nr>.txt (txt, html, xml, pdf, ps, json (metadata))        : rfc,   doc
        |-/rfc-index.txt                                                 : rfc,   idx (idx=index)
        |-/bcp-index.txt                                                 : bcp,   idx
        |-/std-index.txt                                                 : std,   idx
        |-/ien-index.txt                                                 : ien,   idx
        |-/fyi-index.txt                                                 : fyi,   idx
        |-/RFCs_for_errata.txt (only here, case sensitive)               : rfc,   err(ata)
     `-bcp/            bcp<nr>.txt (only txt), also bcp-index.txt        : bcp,   doc
     `-std/            std<nr>.txt (only txt, also std-index.txt         : std,   doc
     `-ien/            ien<nr>.txt (txt, html, pdf), also ien-index.txt  : ien,   doc
     `-fyi/            fyi<nr>.txt (txt, html), also fyi-index.txt       : fyi,   doc
     `-info/           rfc<nr> (no extension)                            : rfc,   inf(o)
     `-inline-errata/  rfc<nr>.html (only html)                          : rfc,   err

    So per series:
    - rfc: idx, doc, inf(o), err(ata), err(ata)-idx
    - bcp: idx, doc
    - std: idx, doc
    - ien: idx, doc
    - fyi: idx, doc

  * also subdirs: rfc/{bcp, std, ien, fyi} with <docid>.ext and series-index.txt
  * terminology:
    - streams - producers of documents: https://www.rfc-editor.org/faq/#streamcat
      Document stream = IETF, IRTF, IAB, Independant
    - Category = (proposed) STD, BCP, Experimental, Informational and Historic (aka status)
    - Series = The RFC series, STD docs are a subseries of the RFC series
      BCP is its own series, like IEN and FYI's
    - Status only applies to RFC's, STD/BCP/IEN/FYI have no status

NOTE:
- :Show lua =require'snacks'.picker.lines() -> new tab with picker return value printed for inspection
- finder:
- matcher:
  * with field:pattern, this matches against item.field=..., so item.author=concat(tags.authors)
    - a nested field (like tags.date won't be used as such a match)
- A picker normally searches only in item.text for a match, not in the results display list lines!
- Example:  > file:. date:may date:2009 -> all items with an item.file on disk dated may 2009
# rfc-editor.org - links
- `:!open https://www.rfc-editor.org/info/rfc8`
- `:!open https://www.rfc-editor.org/rfc/`  (also has /std, /bcp, /fyi, /ien; txt, html, xml, json, ps)
- `:!open https://www.rfc-editor.org/std/`
- `:!open https://www.rfc-editor.org/bcp/`  (txt)
- `:!open https://www.rfc-editor.org/ien/`
- `:!open https://www.rfc-editor.org/fyi/` (txt, html, ps)
- `:!open https://www.rfc-editor.org/rpc/wiki/doku.php?id=rfc_files_available`
- `:!open https://www.rfc-editor.org/rfc/inline-errata/` if errata exists: ..rfc/inline-errata/<docid>.html
- `:!open https://www.rfc-editor.org/rfc/pdfrfc/`  rfc/pdfrfc/<docid>.txt.pdf  (only rfc's)

Examples
- `:!open https://www.rfc-editor.org/rfc/rfc5234.txt` (also: .html, .json (metadata) ..)
- `:!open https://www.rfc-editor.org/rfc/rfc5234.json`
- `:!open https://www.rfc-editor.org/errata/rfc5234`  (this is an html page!)
- `:!open `

--]]

--[[ TYPES ]]

---@alias series "rfc" | "bcp" | "std" | "fyi" | "ien"
---@alias entry { [1]: series, [2]: integer, [3]: string}
---@alias index entry[]
---@alias docid string Unique name for an ietf document

local M = {} -- TODO: review how/why H.methods require M access
-- if not needed anymore, it can move to the [[ MODULE ]] section

--[[ DEPENDENCIES ]]

---@param name string
---@return any dependency the required dependency or nil
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
  -- valid values for series
  valid = { rfc = true, bcp = true, std = true, fyi = true, ien = true },
  top = 'ietf.org', -- subdir under topdir for ietf documents
  sep = '│', -- separator for local index lines: stream|id|text

  -- map categories -> url-type -> url (where rfc, std etc .. are categories)
  -- see https://www.rfc-editor.org/faq/#streamcat
  -- RFCs have status: unknown, proposed standard, internet standard, informational etc ..
  --
  URL_PATTERNS = {
    rfc = {
      index = '<base>/<series>/<series>-index.txt',
      document = '<base>/<series>/<docid>.<ext>',
      errata_index = '<base>/rfc/RFCs_for_errata.txt',
      errata_doc = '<base>/inline-errata/<docid>.html',
      info = '<base>/info/<docid>',
    },
    std = {
      index = '<base>/<series>/<series>-index.txt',
      document = '<base>/<series>/<docid>.<ext>',
    },
    bcp = {
      index = '<base>/<series>/<series>-index.txt',
      document = '<base>/<series>/<docid>.<ext>',
    },
    ien = {
      index = '<base>/<series>/<series>-index.txt',
      document = '<base>/<series>/<docid>.<ext>',
    },
    fyi = {
      index = '<base>/<series>/<series>-index.txt',
      document = '<base>/<series>/<docid>.<ext>',
    },
  },
}

--- fetch an ietf document, save to disk, returns its filename upon success, nil otherwise
-- -@param url string Url for document to retrieve
-- -@return string|nil filename when successful, nil upon failure
-- -@return table? return value
-- function H.fetch(url, fname)
--   -- return a, possibly empty, list of lines
--   -- TODO: use pcall so we do not error out needlessly
--   -- accept:
--   -- txt: headers = {  "content-type: text/plain;          charset=utf-8", "content-length: 12136", },
--   -- html: headers = { "content-type: text/html;           charset=UTF-8", }
--   -- xml: headers = {  "content-type: application/rfc+xml; charset=utf-8", "content-length: 19055", }
--   -- pdf: headers = { , "content-type: application/pdf",   "content-length: 5010729", }
--   local ext = fname:match('%.[^.]+$')
--   local accept = {
--     txt = 'text/plain',
--     html = 'text/html',
--     xml = 'application/xml',
--     pdf = 'applicaiton/pdf',
--   }
--   local ok, rv = pcall(plenary.curl.get, {
--     url = url,
--     accept = accept[ext],
--     output = fname,
--   })
--
--   if ok then
--     return fname, rv
--   else
--     vim.print(vim.inspect({ 'fetch error', rv }))
--     return nil, rv
--   end
-- end

--- find root dir or use cfg.top, fallback to stdpath data dir
---@param spec string|table a top dir relative to rfc-root dir or list of rfc-root dir markers, eg. {'.git'}
---@return string path full path to rfc-top directory (/rfc-root/rfc-top)
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

---@param docid string unique ietf document name, e.g. bcp11 or bcp-index
---@param ext string
---@return string path full file path for `docid.ext` or nil
function H.fname(docid, ext)
  local fdir, fname
  local cfg = M.config
  local top = M.config.top or H.top

  if docid:match('index$') then
    -- it's an document index, ext is always txt
    fname = vim.fs.joinpath(cfg.cache, top, string.format('%s.%s', docid:lower(), 'txt'))

    return vim.fs.normalize(fname)
  end

  -- find fdir based on markers
  local stream = vim.split(docid, '[%d-]')[1]:lower()
  if type(cfg.data) == 'table' then fdir = vim.fs.root(0, cfg.data) end
  fdir = fdir or cfg.data or vim.fn.stdpath('data')
  fname = vim.fs.joinpath(fdir, top, stream, docid:lower() .. '.' .. ext)

  return vim.fs.normalize(fname)
end

-- save to disk, creating directory as needed
-- function H.save(docid, lines)
--   local fname = H.fname(docid, 'txt')
--
--   if fname == nil then return fname end
--
--   if not docid:match('index$') then
--     -- only add modeline for rfc, bcp etc.. not for index files
--     lines[#lines + 1] = '/* vim: set ft=rfc: */'
--   end
--
--   for idx, line in ipairs(lines) do
--     -- snacks.picker.preview.lua, line:find("[%z\1-\8\11\12\14-\31]") -> binary is true
--     -- so keep snacks happy
--     lines[idx] = string.gsub(line, '[%z\1-\8\11\12\14-\31]', '')
--   end
--
--   local dir = vim.fs.dirname(fname)
--   vim.fn.mkdir(dir, 'p')
--   if vim.fn.writefile(lines, fname) < 0 then
--     vim.notify('could not write ' .. docid .. ' to ' .. fname, vim.log.levels.ERROR)
--   end
--
--   return fname
-- end

---@param type string type of document (index, document, errata, info or errata_index)
---@param docid string unique ietf document name or (sub)series
---@param ext string
---@return string|nil url the url for given `docid` and `ext`
function H.url(type, docid, ext)
  -- docid is <series>-index or <stream><nr>

  local series = docid:match('^%D+')
  local url_parts = {
    base = 'https://www.rfc-editor.org',
    docid = docid,
    ext = ext,
    series = series,
  }
  if not H.URL_PATTERNS[series] then return nil end
  -- return url or nil
  local pattern = H.URL_PATTERNS[series][type]
  local url
  if pattern then url = pattern:gsub('(%b<>)', function(key)
    return url_parts[key:sub(2, -2)]
  end) end
  return url
end

--[[ INDEX ]]
-- functions that work with the indices of streams of ietf documents

---@class Index
---@field fetch fun(series: series): index Retrieve (and cache) an index from the ietf
---@field get fun(self: Index, series: series): Index Add an index to Idx
---@field index fun(self: Index, series: series[]): Index Add one or more indices to Idx
local Idx = {
  ERRATA = {},
}

function Idx.errata()
  -- get the errata into Idx.ERRATA { docid -> true }
  local url = H.url('errata_index', 'rfc', 'txt')
  local fname = H.fname('errata', 'txt')
  local ftime = vim.fn.getftime(fname) -- if file unreadable, then ftime = -1
  local ttl = (M.config.ttl or 0) + ftime - vim.fn.localtime()
  if ttl < 1 then
    local ok, rv = pcall(plenary.curl.get, { url = url, accept = 'plain/text' })
    if ok and rv and rv.status == 200 then
      local lines = vim.split(rv.body, '[\r\n]', { trimempty = true })
      for k, n in ipairs(lines) do
        if n and #n > 0 then Idx.ERRATA[('rfc%d'):format(n)] = true end
      end
      local dir = vim.fs.dirname(fname)
      vim.fn.mkdir(dir, 'p')
      if vim.fn.writefile(lines, fname) < 0 then
        vim.notify('[error] could not write errata: ' .. fname, vim.log.levels.ERROR)
      end
    else
      vim.notify('[error] could not get errata', vim.log.levels.ERROR)
    end
  else
    vim.notify('fname is ' .. fname)
    local ok, lines = pcall(vim.fn.readfile, fname)
    if ok then
      for _, nr in ipairs(lines) do
        Idx.ERRATA[('rfc%d'):format(nr)] = true
      end
    else
      vim.notify('!ok, err is ' .. vim.inspect(lines))
    end
  end
  return Idx
end
-- retrieves (and caches) an index for the given `stream` from the ietf
-- returns a list: { {stream, id, text}, .. } or nil on failure
---@param series series a document (sub)series
---@return index index A (possibly empty) list of index entries, { {stream, nr, text}, ..}
function Idx.fetch(series)
  -- retrieve raw content from the ietf
  local url = H.url('index', series, 'txt')
  local idx = {} -- parsed content { {s, n, t}, ... }

  -- retrieve index from the ietf
  local lines = {}
  local ok, rv = pcall(plenary.curl.get, { url = url, accept = 'plain/text' })

  if ok and rv and rv.status == 200 then
    -- formfeed probably not necessary
    lines = vim.split(rv.body, '[\r\n\f]')
  else
    vim.notify('[warn] download failed: [' .. rv.status .. '] ' .. url, vim.log.levels.ERROR)
    return idx -- will be {}
  end

  -- parse assembled line into {stream, id, text}
  ---@param line string
  ---@return entry | nil
  local parse = function(line)
    -- return a parsed accumulated entry line (if any) or nil upon failure
    local nr, title = string.match(line, '^(%d+)%s+(.*)')
    nr = tonumber(nr) -- eleminate any leading zero's
    if nr ~= nil then return { series, nr, title } end
    return nil -- so it actually won't add the entry
  end

  -- assemble and parse lines
  local acc = '' -- accumulated sofar
  local max = series == 'ien' and 3 or 1 -- allow for leading ws in ien index
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
    local fname = H.fname(series, 'txt')
    local dir = vim.fs.dirname(fname)
    vim.fn.mkdir(dir, 'p')
    if vim.fn.writefile(lines, fname) < 0 then
      vim.notify('[error] could not write ' .. series .. ' to ' .. fname, vim.log.levels.ERROR)
    end
  end

  return idx -- { {stream, nr, title }, .. } or empty list
end

-- adds an index (local/remote) for a stream (possibly update cache)
---@param self Index
---@param series series
---@return Index
function Idx:get(series)
  -- get a single stream, either from disk or from ietf
  -- NOTE: we do not check if stream is already present in self
  local idx = {} ---@type index
  local fname = H.fname(series, 'txt')
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
    idx = Idx.fetch(series) or readfile()
  else
    idx = readfile() or Idx.fetch(series)
  end

  if #idx < 1 then
    vim.notify('[warn] no index available for ' .. series, vim.log.levels.WARN) --
  end

  for _, entry in ipairs(idx) do
    table.insert(self, entry)
  end

  return self
end

--- build an index for 1 or more document (sub)series
---@param self Index
---@param series series[]
---@return entry[]
function Idx:from(series)
  -- clear index
  local cnt = #Idx
  for i = 0, cnt do
    Idx[i] = nil
  end

  -- refill
  series = series or { 'rfc' }
  series = type(series) == 'string' and { series } or series
  series = vim.tbl_map(string.lower, series) -- stream names always lowercase
  for _, stream in ipairs(series) do
    assert(H.URL_PATTERNS[stream])
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
---@field details fun(item: table): title: string, ft: string, lines: string[]
---@field from fun(self: Items, series: series[]): Items
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
    -- see: `:!open https://www.rfc-editor.org/rpc/wiki/doku.php?id=rfc_files_available`
    'txt', -- available for all
    'html', -- available for all and only format for rfc/inline-errata
    'xml', -- available from rfc8650 and onwards
    'pdf',
    'ps', -- a few rfc's are available only in postscript
  },

  ACCEPT = { -- accept headers for fetching
    txt = 'text/plain',
    html = 'text/html',
    xml = 'application/xml',
    pdf = 'applicaiton/pdf',
  },
}

--- Builds self.list of picker items, from 1 or more streams; returns #items
---@param self Items
---@param series series[]
---@return Items | nil
function Itms:from(series)
  -- clear self first, TODO: only needed if streams altered or TTL's expired
  local cnt = #Itms
  for i = 0, cnt do
    Itms[i] = nil
  end

  -- refill
  Idx:from(series) -- { {stream, nr, text}, .. }

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

---@param item table the item to retrieve from the rfc editor
---@return table item on success, item.file is set to the local filename; nil otherwise
function Itms.fetch(item)
  -- get an item from the ietf and save it on disk (if possible)
  for _, ext in ipairs(Itms.FORMATS) do
    -- ignore item.format, that is not always accurate; just take 1st available format
    local url = H.url('document', item.docid, ext)
    local fname = H.fname(item.docid, ext)
    local opts = { url = url, accept = Itms.ACCEPT[ext] or 'text/plain', output = fname }
    local ok, rv = pcall(plenary.curl.get, opts)
    if ok and rv and rv.status == 200 then
      item.file = fname
      return item
    else
      if vim.fn.delete(fname) ~= 0 then
        vim.notify('[error] could not delete artifact: ' .. fname, vim.log.levels.ERROR) -- remove artifact
      end
    end
  end
  item.file = nil
  return item
end

--- create a new picker item for given (idx, {stream, id, text})
---@param idx integer
---@param entry entry
---@return table | nil item fields parsed from an index entry's text or nil
function Itms.new(idx, entry)
  -- TODO:
  -- [ ] rfc status '-' is Not issued, n/a for bcp, std or others (use stream as status)
  local item = nil -- returned if entry is malformed
  local stream, id, text = unpack(entry)
  stream = stream:lower() -- just in case
  local docid = ('%s%s'):format(stream, id)
  local errata = Idx.ERRATA[docid] and 'yes' or 'no'
  if docid == 'rfc2' then vim.print(vim.inspect({ docid, errata, Idx.ERRATA[docid] })) end

  if stream and id and text then
    item = {
      idx = idx,
      score = idx,
      text = text, -- used by snack matcher
      title = string.format('%s%s', stream, id):upper(), -- used by snack as preview win title

      -- extra fields to search on using > field:term in search prompt
      errata = errata,
      docid = string.format('%s%s', stream:lower(), tonumber(id)),
      name = string.format('%s%d', stream, id):upper(),
      stream = stream:lower(),
    }

    -- update fields in item
    Itms.set_tags(item)
    Itms.set_file(item)
  end

  return item -- if nil, won't get added to the list
end

--- Sets item.file to the first filename on disk (if any) in order of Itms.FORMATS
---@param item table
---@return table item sets item.file, either the first filename found or nil (missing)
function Itms.set_file(item)
  item.file = nil -- nothing found yet
  for _, ext in ipairs(Itms.FORMATS) do
    local fname = H.fname(item.docid, ext)
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
  -- for RFC's that are not issued, there won't be a status. Others donot have a status
  local tags = {
    -- ensure these tags are present with a default value
    obsoletes = 'n/a',
    obsoleted_by = 'n/a',
    updates = 'n/a',
    updated_by = 'n/a',
    also = 'n/a',
    status = 'n/a',
    format = '', -- empty string means no format(s) listed/found
    doi = 'n/a',
    -- these two are not `()`-constructs
    authors = 'n/a',
    date = 'n/a',
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
function Itms.details(item)
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
    url = H.url('document', item.docid, 'txt') .. ' (*maybe*)'
  else
    url = H.url('document', item.docid, ext)
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

---@param ctx snacks.Picker
---@param title string
---@param lines string[]
---@param ft string
function Itms._set_preview(ctx, title, lines, ft)
  -- see snacks.picker.core.preview for the preview funcs used below
  ctx.preview:reset() -- REVIEW: necessary ?
  ctx.preview:set_lines(lines)
  ctx.preview:set_title(title)
  ctx.preview:highlight({ ft = ft })
end

function Itms.preview(ctx)
  -- called when ctx.item becomes the current one in the results list

  if ctx.item.file and ctx.item.file:match('%.txt$') then
    -- preview ourselves, since snacks trips over any formfeeds in the txt-file
    -- REVIEW: this reads the file every time, could cache that in _preview?
    local ok, lines = pcall(vim.fn.readfile, ctx.item.file)
    local title, ft

    if not ok then
      -- fallback to preview item itself (ft will be markdown)
      title, ft, lines = Itms.details(ctx.item)
    else
      title = ctx.item.docid:upper()
      ft = 'rfc' -- since we're looking at the text itself
    end
    Itms._set_preview(ctx, title, lines, ft)
  elseif ctx.item._preview then
    -- we've seen it before, use previously assembled info
    local m = ctx.item._preview
    Itms._set_preview(ctx, m.title, m.lines, m.ft)
  else
    -- use item._preview: since item.preview={text="..", ..} means text will be split every time
    local title, ft, lines = Itms.details(ctx.item)
    Itms._set_preview(ctx, title, lines, ft)
    ctx.item._preview = { title = title, ft = ft, lines = lines } -- remember for next time
  end
end

--[[ Actions ]]
-- TODO:
-- [ ] configurable: select before download or default to 1st in line
-- [ ] configurable open action: select or edit, tabnew, !open as appropiate
--     sometimes you want to see the html/xml in neovim itself?

local Act = {
  actions = {}, -- functions to be defined later on, as referenced by win.list/input.keys
  -- see `!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/config/defaults.lua`
  win = {
    -- temp mappings during search, ',<x>' since ',' usually isn't used in searches
    -- TODO, add:
    -- [*] 'M' for meta data (json) -- how to store this?
    -- [*] 'E' for errata? -- open browser for the inline-errata (if it exists)
    -- [*] 'S' to open rfc-editor search?
    --
    list = { -- the results list window
      keys = {
        ['F'] = { 'fetch', mode = { 'n' } },
        ['R'] = { 'remove', mode = { 'n' } },
        ['O'] = { 'confirm', mode = { 'n' } },
        ['I'] = { 'inspect', mode = { 'n' } },
        ['S'] = { 'search', mode = { 'n' } },
      },
    },
    input = { -- the input window where search is typed
      keys = {
        ['F'] = { 'fetch', mode = { 'n' } },
        ['R'] = { 'remove', mode = { 'n' } },
        ['O'] = { 'confirm', mode = { 'n' } },
        ['I'] = { 'inspect', mode = { 'n' } },
        ['S'] = { 'search', mode = { 'n' } },
      },
    },
  },
}

function Act.actions.fetch(picker, curr_item)
  -- curr_item == picker.list:current()
  local items = picker.list.selected
  if #items == 0 then items = { curr_item } end
  local notices = { '# Fetch:\n' }

  for n, item in ipairs(items) do
    Itms.fetch(item) -- upon success, sets item.file

    if item.file then
      item._preview = nil
      picker.list:unselect(item)
      picker.list:update({ force = true })
      picker.preview:show(picker, { force = true })
      notices[#notices + 1] = string.format('- (%d/%s) %s - success', n, #items, item.docid)
    else
      notices[#notices + 1] = string.format('- (%d/%s) %s - failed!', n, #items, item.docid)
    end
  end
  vim.notify(table.concat(notices, '\n'), vim.log.levels.INFO)
end

function Act.actions.inspect(picker, item)
  -- set preview to show item table
  -- local lines = { '# ' .. item.docid:upper(), ' \r\n', ' \r\n', '## Details', '\n', '```luai\n', '\n', '{' }
  local lines = { '\n# ' .. item.docid:upper(), '\n\n## Item fields\n\n```lua\n{\n' }
  local keys = {}
  for k, _ in pairs(item) do
    if not k:match('^_') then keys[#keys + 1] = k end
  end
  table.sort(keys)

  for _, key in ipairs(keys) do
    -- use vim.inspect for value (may not always be string or number)
    lines[#lines + 1] = string.format('  %-15s= %s', key, vim.inspect(item[key]))
  end
  lines[#lines + 1] = '\n}\n\n```'

  Itms._set_preview(picker, item.title, lines, 'markdown')
end

function Act.actions.remove(picker, curr_item)
  -- curr_item == picker.list:current() ?= picker:current()
  local items = picker.list.selected
  if #items == 0 then items = { curr_item } end
  local notices = { '# Remove:\n' }

  for n, item in ipairs(items) do
    local result
    if item.file and vim.fn.filereadable(item.file) == 1 then
      local rv = vim.fn.delete(item.file)
      if rv == 0 then
        result = 'removed'
        item.file = nil
      else
        -- keep unreadable item.file
        result = 'failed!'
      end
    elseif item.file then
      result = 'not found'
    else
      result = 'no file item'
    end
    Itms.set_file(item) -- set .file: maybe other formats are still there
    picker.list:unselect(item) -- whether selected or not ..
    picker.list:update({ force = true })
    picker.preview:show(picker, { force = true })
    notices[#notices + 1] = string.format('- (%d/%s) %s - %s', n, #items, item.docid, result)
  end
  vim.notify(table.concat(notices, '\n'), vim.log.levels.INFO)
end

function Act.actions.search(_, item) -- ignores picker, item
  local info = { rfc = true, bcp = true, std = true }
  if info[item.stream] then
    vim.cmd(('!open https://rfc-editor.org/info/%s'):format(item.docid))
  else
    vim.notify('[info] no info page for ' .. item.docid, vim.log.levels.INFO)
  end
end

function Act.confirm(picker, item)
  picker:close()
  if not item.file then
    Itms.fetch(item) -- upon success, sets item.file
  end

  if item.file and item.file:match('%.txt$') then
    -- edit in nvim
    vim.cmd(M.config.edit .. ' ' .. item.file)
    local ext = item.file:match('%.[^%.]+$')
    local ft = M.config.filetype[ext]
    if ft then
      vim.cmd('set ft=' .. ft) -- TODO: M.config candidate
    end
  elseif item.file then
    -- TODO: Brave browser can't access .local/data files ..
    vim.cmd('!open ' .. item.file)
  end
end

--[[ Module ]]

M.config = {
  cache = vim.fn.stdpath('cache'), -- store indices only once
  data = vim.fn.stdpath('data'), -- path or markers
  top = 'ietf.org',
  ttl = 4 * 3600, -- time-to-live [second], before downloading again
  edit = 'tabedit ',
  filetype = {
    txt = 'rfc',
  },
}

function M.reload()
  -- for developing
  vim.keymap.set('n', '<space>r', ":lua require'pdh.rfc'.reload()<cr>")
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

    format = Itms.format,
    preview = Itms.preview,
    actions = Act.actions,
    confirm = Act.confirm,
    win = Act.win,

    layout = { fullscreen = true },
  })
end

function M.select()
  local choices = Itms.FORMATS
  for idx, v in ipairs(choices) do
    v = v .. '|' .. ' ' .. H.fname('rfc123', v)
    choices[idx] = v
  end
  vim.ui.select(choices, {
    prompt = 'Select extension to download',
  }, function(choice)
    if choice == nil then choice = 'cancelled' end
    -- vim.print('your choice: ' .. choice)
  end)
end

function M.test_bit(docid)
  -- status could also be either nil or 1st ext found (txt, html etc..)
  -- or even nil vs { ext's }
  -- then there would be no need for bit op shenanigans
  -- snacks.input overrides vim.ui.input
  -- check out snacks.picker.select, snacks.util.spinner, plenary popup,
  -- plenary has a plenary.select
  docid = docid and docid:lower() or 'rfc1'
  bit = require 'bit'

  local masks = {
    txt = 0x01,
    html = 0x02,
    pdf = 0x04,
    xml = 0x08,
  }

  local status = 0x00
  for ext, mask in pairs(masks) do
    local fname = H.fname(docid, ext)
    if vim.fn.filereadable(fname) == 1 then status = bit.bor(status, mask) end
  end

  local fext = {}
  for ext, mask in pairs(masks) do
    if bit.band(status, mask) ~= 0 then fext[#fext + 1] = ext end
  end

  -- vim.print(stream .. id .. ' available formats are: ' .. vim.inspect(fext))
end

function M.test()
  Idx.errata()
  local count = 1
  for n, entry in pairs(Idx.ERRATA) do
    count = count + 1
    vim.print(vim.inspect({ n, entry, Idx.ERRATA['rfc2'] }))
    if count > 10 then break end
  end
end

vim.keymap.set('n', '<space>r', ":lua require'pdh.rfc'.reload()<cr>")

return M
