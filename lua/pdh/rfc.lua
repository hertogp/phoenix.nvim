--[[

Easily search, download and read ietf rfc's.
- some entry points
  * `:!open https://www.rfc-editor.org/rfc/rfc-index.txt`
  * `:!open https://www.rfc-editor.org/rfc/rfc-ref.txt`
  * `:!open https://www.rfc-editor.org/rfc/rfc-index.xml` -- rfc<x>.json contains the values as well
  * `:!open https://www.rfc-editor.org/info/rfc8`
  * `:!open https://www.rfc-editor.org/rfc/`  (also /std, /bcp, /fyi, /ien)
  * `:!open https://www.rfc-editor.org/rpc/wiki/doku.php?id=rfc_files_available`
  * `:!open https://www.rfc-editor.org/rfc/inline-errata/` if errata exists: ..rfc/inline-errata/<docid>.html
  * `:!open https://www.rfc-editor.org/rfc/pdfrfc/`  rfc/pdfrfc/<docid>.txt.pdf  (only rfc's)
  * `:!open https://www.rfc-editor.org/rfc/rfc5234.txt` (also: .html, .json (metadata) ..)
  * `:!open https://www.rfc-editor.org/rfc/rfc5234.json`
  * `:!open https://www.rfc-editor.org/errata/rfc5234`  (this is an html page!)

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

--]]

--[[ TYPES ]]

---@alias series "rfc" | "bcp" | "std" | "fyi" | "ien"
---@alias entry { [1]: series, [2]: integer, [3]: string}
---@alias index entry[]

local M = {} -- TODO: review how/why H.methods require M access
-- if not needed anymore, it can move to the [[ MODULE ]] section

--[[ DEPENDENCIES ]]

---@param name string
---@return any dependency the required dependency or go bust
local function dependency(name)
  local ok, var = pcall(require, name)
  assert(ok, ('[error] missing dependency: '):format(name), vim.log.levels.ERROR)
  return var
end

-- check all dependencies before bailing (if applicable)
local plenary = dependency('plenary')
local snacks = dependency('snacks')

--[[ HELPERS ]]
-- H.methods assert and may fail, so caller beware & be responsible

---@class Helper helper table
---@field URL_PATTERNS table maps doctype->(sub)series->url patterns
---@field FNAME_PATTERN table maps doctype->(sub)series->fname patterns
---@field top string top (sub)dir under data/cache dir where the rfc files are stored
---@field sep string separator used in index files: { {series|nr|text}, .. }
---@field dir fun(spec:string|table):string cache/data directory path or bust
---@field fname fun(type:string, docid:string, ext:string):string fname or bust
---@field url fun(type:string, docid:string, ext:string):string|nil url or bust
local H = {
  -- fallbacks if M.config fails for some reason
  top = 'ietf.org', -- subdir under topdir for ietf documents
  sep = '│', -- separator for local index lines: series|id|text
  on = '●', --- ',  ,  , 
  off = '○', -- ',  ,  ,  ,

  URL_PATTERNS = {
    -- { series = { doc-type = pattern } }
    rfc = {
      index = '<base>/<series>/<series>-index.txt',
      document = '<base>/<series>/<docid>.<ext>',
      errata_index = '<base>/rfc/RFCs_for_errata.txt',
      errata = '<base>/errata/<docid>',
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

  FNAME_PATTERNS = {
    -- { series = { doc-type = { pattern } }
    rfc = {
      document = '<data>/<top>/<series>/<docid>.<ext>',
      index = '<cache>/<top>/<series>-index.<ext>',
      errata_index = '<cache>/<top>/<series>-errata.<ext>',
    },
    std = {
      document = '<data>/<top>/<series>/<docid>.<ext>',
      index = '<cache>/<top>/<series>-index.txt',
    },
    bcp = {
      document = '<data>/<top>/<series>/<docid>.<ext>',
      index = '<cache>/<top>/<series>-index.txt',
    },
    ien = {
      document = '<data>/<top>/<series>/<docid>.<ext>',
      index = '<cache>/<top>/<series>-index.txt',
    },
    fyi = {
      document = '<data>/<top>/<series>/<docid>.<ext>',
      index = '<cache>/<top>/<series>-index.txt',
    },
  },
}

--- fetch an ietf document, save to disk, returns its filename upon success, nil otherwise
-- -@param url string Url for document to retrieve
-- -@param fname string filename to download to
-- -@param body? boolean return ok, lines instead of ok, fname
-- -@return string|nil filename when successful, nil upon failure
-- -@return table? return value
-- function H.fetch(url, fname)
--   -- return a, possibly empty, list of lines
--   local ext = fname:match('%.[^.]+$')
--   local ok, rv = pcall(plenary.curl.get, {
--     url = url,
--     accept = accept[ext],
--     output = fname,
--   })
--
--   if ok then
--     return fname, rv
--   else
--     -- TODO: remove output file, don't wanne leave artifacts behind
--     vim.print(vim.inspect({ 'fetch error', rv }))
--     return nil, rv
--   end
-- end

--- find root dir or use cfg.top, fallback to stdpath data dir
---@param spec string|table a top dir relative to Rfc-root dir or list root dir markers, eg. {'.git'}
---@return string path full path to rfc-top directory (/rfc-root/rfc-top) (or go bust)
function H.dir(spec)
  local path

  if type(spec) == 'table' then
    -- find root dir based on markers in cfg.data
    path = vim.fs.root(0, spec)
  elseif type(spec) == 'string' then
    path = vim.fs.normalize(spec)
  end

  return assert(path, ('invalid directory specification %s'):format(vim.inspect(spec)))
end

---@alias doctype 'document'|'index'|'errata_index' Last one is rfc specific
---@alias urltype 'document'|'index'|'errata_index'|'errata'|'info' Last three are rfc specific

---Translate document type, id and extension to a local filename (or die trying)
---@param doctype doctype type of document (index, document, info, ..)
---@param docid string unique document name (<series><nr>)
---@param ext string file extension
---@return string path full file path for doc-type and docid or bust!
function H.fname(doctype, docid, ext)
  local series = docid:match('%D+'):lower()
  local fname_parts = {
    cache = H.dir(M.config.cache),
    data = H.dir(M.config.data),
    series = series,
    docid = docid,
    top = M.config.top or H.top,
    ext = ext,
  }

  assert(H.FNAME_PATTERNS[series], ('fname: series %s is not valid'):format(series))
  assert(H.FNAME_PATTERNS[series][doctype], ('fname: type %s not valid for %s series'):format(doctype, series))
  local pattern = H.FNAME_PATTERNS[series][doctype]
  local fname = pattern:gsub('<(.-)>', fname_parts)
  return fname
end

---@param urltype urltype type of document (index, document, errata, info or errata_index)
---@param docid string unique document name (<series><nr>) or (sub)series
---@param ext string
---@return string|nil url the url for given `docid` and `ext`
function H.url(urltype, docid, ext)
  -- docid is <series>-index or <series><nr>

  local url = nil
  local series = docid:match('^%D+')
  local url_parts = {
    base = 'https://www.rfc-editor.org',
    docid = docid,
    series = series,
    ext = ext,
  }
  if H.URL_PATTERNS[series] then
    local pattern = H.URL_PATTERNS[series][urltype]
    if pattern then
      url = pattern:gsub('<(.-)>', url_parts) -- '<(%S+)> won't work?
    end
  end
  return url
end

--[[ INDEX ]]
-- functions that work with the indices of (sub)series (rfc, std, ..)

---@class Index
---@field ERRATA table map rfc<nr>-> true iff errata exist
---@field errata fun(self: Index): Index updates self.ERRATA table
---@field fetch fun(series: series): index Retrieve (and cache) an index from the ietf
---@field get fun(self: Index, series: series): Index Add an index to Idx
---@field from fun(self: Index, series: series[]): Index Add one or more indices to Idx
local Idx = {
  ERRATA = {},
}

---@param self Index
---@return Index index updates self.ERRATA from the errata index
function Idx:errata()
  -- get the errata into Idx.ERRATA { docid -> true }
  local url = H.url('errata_index', 'rfc', 'txt')
  local fname = assert(H.fname('errata_index', 'rfc', 'txt'))
  local ftime = vim.fn.getftime(fname) -- if file unreadable, then ftime = -1
  local ttl = (M.config.ttl or 0) + ftime - vim.fn.localtime()
  if ttl < 1 then
    -- read from the net
    local ok, rv = pcall(plenary.curl.get, { url = url, accept = 'plain/text' })
    if ok and rv and rv.status == 200 then
      local lines = vim.split(rv.body, '[\r\n]', { trimempty = true })
      for _, n in ipairs(lines) do
        if n and #n > 0 then
          Idx.ERRATA[('rfc%d'):format(n)] = true
        end
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
    -- read from disk
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

-- retrieves (and caches) an index for the given (sub)`series` from the ietf
-- returns a list: { {series, id, text}, .. } or nil on failure
---@param series series a document (sub)series
---@return index index A (possibly empty) list of index entries, { {series, nr, text}, ..}
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

  -- parse assembled line into {series, id, text}
  ---@param line string
  ---@return entry | nil
  local parse = function(line)
    -- return a parsed accumulated entry line (if any) or nil upon failure
    local nr, title = string.match(line, '^(%d+)%s+(.*)')
    nr = tonumber(nr) -- eleminate any leading zero's
    if nr ~= nil then
      return { series, nr, title }
    end
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
    local fname = H.fname('index', series, 'txt')
    local dir = vim.fs.dirname(fname)
    vim.fn.mkdir(dir, 'p')
    if vim.fn.writefile(lines, fname) < 0 then
      vim.notify('[error] could not write ' .. series .. ' to ' .. fname, vim.log.levels.ERROR)
    end
  end

  return idx -- { {series, nr, title }, .. } or empty list
end

-- adds an index (local/remote) for a series (possibly update cache)
---@param self Index
---@param series series
---@return Index
function Idx:get(series)
  -- get a single series, either from disk or from ietf
  -- NOTE: we do not check if series is already present in self
  local idx = {} ---@type index
  local fname = H.fname('index', series, 'txt')
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

  -- refill items
  series = series or { 'rfc' }
  series = type(series) == 'string' and { series } or series
  series = vim.tbl_map(string.lower, series) -- series name is always lowercase
  for _, series_name in ipairs(series) do
    assert(H.URL_PATTERNS[series_name])
    Idx:get(series_name)
  end

  -- refill ERRATA
  Idx:errata()

  return self
end

--[[ ITEM ]]
--- state and functions that work with picker items

---@class Items
---@field ICONS table map true/false to an icon for display in results window
---@field FORMATS table ordered list of supported formats for douments
---@field ACCEPT table maps extentions to `accept` field ivalues in a HTTP header
---@field details fun(ctx: table): title:string, ft:string, lines:string[]
---@field fetch fun(item:table): item:table
---@field format fun(item:table): string[]
---@field from fun(self: Items, series: series[]): Items
---@field new fun(idx: integer, entry: entry): item:table
---@field preview fun(ctx:table):nil
---@field set_file fun(item: table):table
---@field set_tags fun(item: table):table
---@field _set_preview fun(ctx:table, title:string, lines:string[], ft:string):nil
local Itms = {
  ICONS = {
    -- NOTE: add a space after the icon (it is used as-is here)
    [false] = ' ',
    [true] = ' ',
  },

  FORMATS = { -- order is important: first one available (disk/net) is used
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
    ps = 'applicaiton/ps',
  },
}

--- returns `title`, `ft`, `lines` for use in a preview
--- (used when no local file is present to be previewd)
---@param item table An item of the picker result list
---@return string title The title for an item
---@return string ft The filetype to use when previewing
---@return string[] lines The lines to display when previewing
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
  local url
  local ext = vim.split(item.format, ',%s*')[1] -- for (possible) url
  if #ext == 0 then
    url = H.url('document', item.docid, 'txt') .. ' (*maybe*)'
  else
    url = H.url('document', item.docid, ext)
  end
  local lines = {
    '',
    ('# %s'):format(item.name),
    '',
    '',
    ('## %s'):format(item.text),
    '',
    fmt2cols:format('AUTHORS', item.authors),
    fmt2cols:format('STATUS', item.status:upper()),
    fmt2cols:format('DATE', item.date or '-'),
    '',
    fmt2cols:format('SERIES', item.series:upper()),
    fmt2cols:format('FORMATS', item.format:upper()),
    fmt2cols:format('DOI', item.doi:upper()),
    '',
    '',
    '### TAGS',
    '',
    fmt2cols:format('ALSO', item.also:upper()),
    fmt2cols:format('OBSOLETES', item.obsoletes:upper()),
    fmt2cols:format('OBSOLETED by', item.obsoleted_by:upper()),
    fmt2cols:format('UPDATES', item.updates:upper()),
    fmt2cols:format('UPDATED by', item.updated_by:upper()),
    '',
    '',
    '### PATH',
    '',
    fmt2path:format('CACHE', cache),
    fmt2path:format('DATA', data),
    fmt2path:format('FILE', file),
    '',
    fmt2path:format('URL', url),
  }

  return title, ft, lines
end

--- Retrieves an item's document from the rfc-editor
---@param item table the item to retrieve from the rfc editor
---@return table item on success, item.file is set to the local filename; nil otherwise
function Itms.fetch(item)
  -- get an item from the ietf and save it on disk (if possible)
  for _, ext in ipairs(Itms.FORMATS) do
    -- ignore item.format, that is not always accurate; just take 1st available format
    local url = H.url('document', item.docid, ext)
    local fname = H.fname('document', item.docid, ext)
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

--- Builds self.list of picker items, from 1 or more (sub)series; returns #items
---@param self Items
---@param series series[]
---@return Items | nil
function Itms:from(series)
  -- clear self first, TODO: only needed if series altered or TTL's expired
  local cnt = #Itms
  for i = 1, cnt do
    Itms[i] = nil
  end

  -- refill
  Idx:from(series) -- { {series, nr, text}, .. }

  if #Idx == 0 then
    return nil
  end

  for idx, entry in ipairs(Idx) do
    table.insert(self, Itms.new(idx, entry))
  end
  return self
end

--- create a new picker item for given (idx, {series, id, text})
---@param idx integer
---@param entry entry
---@return table|nil item fields parsed from an index entry's text or nil
function Itms.new(idx, entry)
  local item = nil -- returned if entry is malformed
  local series, id, text = unpack(entry)
  series = series:lower() -- just in case
  local docid = ('%s%s'):format(series, id)
  local errata = Idx.ERRATA[docid] and 'yes' or 'no'

  if series and id and text then
    item = {
      idx = idx,
      score = idx,
      text = text, -- used by snacks.picker's matcher
      title = ('%s%s'):format(series, id):upper(), -- used by snack as preview win title

      -- extra fields to search on using > field:term in search prompt
      errata = errata,
      docid = ('%s%s'):format(series, id),
      name = ('%s%d'):format(series, id):upper(),
      series = series:lower(),
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
    local fname = H.fname('document', item.docid, ext)
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

  -- fix item.formats value (keep only the known ext labels, if any)
  local seen = {}
  for _, fmt in ipairs(Itms.FORMATS) do
    if item.format:match(fmt) then
      seen[#seen + 1] = fmt
    end
  end
  if #seen > 0 then
    item.format = table.concat(seen, ', ')
  end

  -- extract date
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

--- sets the contents of the picker preview window
---@param ctx table
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

---@param ctx table picker object
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

---@class Actions
---@field actions table
---@field win table
---@field actions.fetch fun(picker:table, curr_item:table)
---@field actions.inspect fun(picker:table, item:table)
---@field actions.remove fun(picker:table, curr_item:table)
---@field actions.visit_info fun(_, item:table)
---@field actions.visit_page fun(_, item:table)
---@field actions.visit_errate fun(_, item:table)
local Act = {
  actions = {}, -- functions to be defined later on, as referenced by win.list/input.keys
  -- see `!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/config/defaults.lua`
  win = {
    list = { -- the results list window
      keys = {
        ['F'] = { 'fetch', mode = { 'n' } },
        ['R'] = { 'remove', mode = { 'n' } },
        ['O'] = { 'confirm', mode = { 'n' } },
        ['I'] = { 'inspect', mode = { 'n' } },
        ['gi'] = { 'visit_info', mode = { 'n' } },
        ['ge'] = { 'visit_errata', mode = { 'n' } },
        ['gx'] = { 'visit_page', mode = { 'n' } },
      },
    },
    input = { -- the input window where search is typed
      keys = {
        ['F'] = { 'fetch', mode = { 'n' } },
        ['R'] = { 'remove', mode = { 'n' } },
        ['O'] = { 'confirm', mode = { 'n' } },
        ['I'] = { 'inspect', mode = { 'n' } },
        ['gi'] = { 'visit_info', mode = { 'n' } },
        ['ge'] = { 'visit_errata', mode = { 'n' } },
        ['gx'] = { 'visit_page', mode = { 'n' } },
      },
    },
  },
}

--- retrieves one or more item(s) from the rfc-editor
---@param picker table current picker in action
---@param curr_item table the current item in pickers results window
function Act.actions.fetch(picker, curr_item)
  -- curr_item == picker.list:current()
  local items = picker.list.selected
  if #items == 0 then
    items = { curr_item }
  end
  local notices = { '# Fetch:\n' }

  for n, item in ipairs(items) do
    Itms.fetch(item) -- upon success, sets item.file

    if item.file then
      item._preview = nil
      picker.list:unselect(item)
      picker.list:update({ force = true })
      picker.preview:show(picker, { force = true })
      notices[#notices + 1] = ('- (%d/%s) %s - success'):format(n, #items, item.docid)
    else
      notices[#notices + 1] = ('- (%d/%s) %s - failed!'):format(n, #items, item.docid)
    end
  end
  vim.notify(table.concat(notices, '\n'), vim.log.levels.INFO)
end

--- sets the preview window contents to a dump of the item table
---@param picker table current picker in action
---@param item table the current item in pickers results window
function Act.actions.inspect(picker, item)
  -- set preview to show item table
  -- local lines = { '# ' .. item.docid:upper(), ' \r\n', ' \r\n', '## Details', '\n', '```luai\n', '\n', '{' }
  local lines = { '\n# ' .. item.docid:upper(), '\n\n## Item fields\n\n```lua\n{\n' }
  local keys = {}
  for k, _ in pairs(item) do
    if not k:match('^_') then
      keys[#keys + 1] = k
    end
  end
  table.sort(keys)

  for _, key in ipairs(keys) do
    -- use vim.inspect for value (may not always be string or number)
    lines[#lines + 1] = ('  %-15s= %s'):format(key, vim.inspect(item[key]))
  end
  lines[#lines + 1] = '\n}\n\n```'

  Itms._set_preview(picker, item.title, lines, 'markdown')
end

function Act.actions.remove(picker, curr_item)
  -- curr_item == picker.list:current() ?= picker:current()
  local items = picker.list.selected
  if #items == 0 then
    items = { curr_item }
  end
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
    notices[#notices + 1] = ('- (%d/%s) %s - %s'):format(n, #items, item.docid, result)
  end
  vim.notify(table.concat(notices, '\n'), vim.log.levels.INFO)
end

--- Visits the info page of the current item
---@param _ table
---@param item table the current item at the time of the keypress
function Act.actions.visit_info(_, item)
  local url = H.url('info', item.docid, 'html')
  if url then
    vim.cmd(('!open %s'):format(url))
  end
end

--- Visits the html page of the current item
---@param _ table
---@param item table the current item at the time of the keypress
function Act.actions.visit_page(_, item)
  local url = H.url('document', item.docid, 'html')
  if url then
    vim.cmd(('!open %s'):format(url))
  end
end

--- Visits the errate page (if any) of the current (rfc) item
---@param _ table
---@param item table the current item at the time of the keypress
function Act.actions.visit_errata(_, item)
  local url = H.url('errata', item.docid, '')
  if url then
    vim.cmd(('!open %s'):format(url))
  end
end

--- Open the current item, either is neovim (txt) or via `open` for other formats
---@param picker table
---@param item table the current item at the time of the keypress
function Act.confirm(picker, item)
  picker:close()
  if not item.file then
    Itms.fetch(item) -- upon success, sets item.file
  end

  if item.file and item.file:lower():match('%.txt$') then
    -- edit in nvim
    vim.cmd(M.config.edit .. ' ' .. item.file)
    local ft = M.config.filetype['txt']
    if ft then
      vim.cmd('set ft=' .. ft)
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

function M.reload(opts)
  -- for developing
  vim.keymap.set('n', '<space>r', ":lua require'pdh.rfc'.reload()<cr>")
  opts = opts or {}
  require('plenary.reload').reload_module('plenary')
  require('plenary.reload').reload_module('pdh.rfc')
  require('pdh.rfc').setup(opts)
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
  M.config.data = H.dir(M.config.data)
  M.config.cache = H.dir(M.config.cache)
  M.config.series = M.config.series or { 'rfc', 'bcp', 'std' }
  -- load up the Idx and Itms tables
  Itms:from(M.config.series)

  return M
end

function M.search(series)
  -- search the (sub)series index/indices
  -- TODO:
  -- [ ] check if indices need refreshing ..

  if #Itms < 1 then
    Itms:from(series)
  end

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
    v = v .. '|' .. ' ' .. H.fname('document', 'rfc123', v)
    choices[idx] = v
  end
  vim.ui.select(choices, {
    prompt = 'Select extension to download',
  }, function(choice)
    if choice == nil then
      choice = 'cancelled'
    end
  end)
end

function M.toggle()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  local char = vim.api.nvim_buf_get_text(buf, row - 1, col, row - 1, col + 1, {})
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
  if line:match(H.on) then
    line = line:gsub(H.on, H.off)
  else
    line = line:gsub(H.off, H.on)
  end
  vim.api.nvim_set_option_value('modifiable', true, { scope = 'local', buf = buf })
  vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { line })
  vim.api.nvim_set_option_value('modifiable', false, { scope = 'local', buf = buf })
  -- print(vim.inspect({ buf, row, col, char, line }))
end
--
function M.test()
  -- test plenary.popup:
  -- * new option winborder -> can't use plenary's border (second window behind popup window)
  --   with winborder enables (global opt), inner window vim-border overwrites
  --   plenary's border.  Plenary's border window also gets the vim-border
  --   making it all look weird.  So workaround is:
  --   + don't use plenary's border
  --   + use winborder plus nvim_win_set_config op plenary's popup window
  local popup = require 'plenary'.popup
  local function f(t)
    return H.on .. H.sep .. t
  end
  local what = { f('rfc'), f('std'), f('bcp'), f('ien'), f('fyi') }

  local cb_fun = function(win, _) -- ignore (current) line
    local bufnr = vim.api.nvim_win_get_buf(win)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    print(vim.inspect({ 'cb lines', lines }))
  end

  local cb_final = function(win, buf)
    vim.api.nvim_buf_set_keymap(buf, 'n', '<tab>', ":lua require'pdh.rfc'.toggle()<cr>", {})
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close!<cr>', {})
    print(vim.inspect({ 'finalize', win, buf }))
  end

  -- see `:!open https://github.com/nvim-telescope/telescope.nvim/blob/b4da76be54691e854d3e0e02c36b0245f945c2c7/lua/telescope/actions/init.lua#L1383C3-L1397C4`
  local opts = {
    -- show title, it won't show since border win and popup win overlap exactly
    focusable = true,
    border = false, -- border is drawn in a second window of itself (with its own border)
    -- title crap above
    relative = 'editor',
    cursorline = true,
    minwidth = 20,
    padding = { 0, 0, 0, 1 },
    callback = cb_fun,
    finalize_callback = cb_final,
  }
  local cwin, cfg = popup.create(what, opts)
  local cbuf = vim.api.nvim_win_get_buf(cwin)
  vim.api.nvim_set_option_value('modifiable', false, { scope = 'local', buf = cbuf })
  -- vim.cmd('mapclear ' .. cbuf)
  print(vim.inspect({
    'bwin',
    vim.api.nvim_win_set_config(cwin, { title = { { 'Series', 'Constant' } }, footer = 'footer' }),
  }))

  -- local bwin = cfg.border.win_id
  -- local bbuf = cfg.border.bufnr
  -- local blines = vim.api.nvim_buf_get_lines(bbuf, 0, -1, false)
  -- print(vim.inspect({ 'cfg', cfg, 'win', win }))
  -- print(vim.inspect({ 'blines', blines }))
  -- print(vim.inspect({ 'c.b.contents', cfg.border.contents }))
  -- vim.api.nvim_buf_set_lines(bbuf, 0, -1, false, cfg.border.contents)
end

function M.pop()
  -- rewrite:
  -- * buffer lines are formatted bufvar entries
  -- * use buffer var to hold options to toggle as data {option, true/false}
  -- * use format func to display and toggle
  -- * no need to parse buffer upon accept (var is current state as reflected by buf lines)
  local function f(t, on)
    local state = on == nil and H.on or on and H.on or H.off
    return (' %s%s %s'):format(state, H.sep, t)
  end
  local function toggle()
    -- toggle H.on/H.off on current line (finds 1st occurrence on the line)
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local on = line:match(H.on)
    local n, m
    print(vim.inspect({ n, m }))
    if on then
      line = line:gsub(H.on, H.off)
      n, m = line:find(H.off, 1, true)
    else
      line = line:gsub(H.off, H.on)
      n, m = line:find(H.on, 1, true)
    end
    vim.api.nvim_set_option_value('modifiable', true, { scope = 'local', buf = buf })
    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { line })
    local ns_id = vim.api.nvim_get_namespaces()['pdh.rfc']
    if on and n then
      vim.api.nvim_buf_set_extmark(
        buf,
        ns_id,
        row - 1,
        n - 1,
        { end_line = row - 1, end_col = m - 1, hl_group = 'Float' }
      )
    elseif n then
      vim.api.nvim_buf_set_extmark(
        buf,
        ns_id,
        row - 1,
        n - 1,
        { end_line = row - 1, end_col = m - 1, hl_group = 'Character' }
      )
    end
    vim.api.nvim_set_option_value('modifiable', false, { scope = 'local', buf = buf })
    -- print(vim.inspect({ buf, row, col, char, line }))
  end

  local function enter()
    -- choices accepted
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    print(vim.inspect({ 'enter', lines }))
    vim.api.nvim_win_close(win, true) -- this also deletes the (scratch) buffer
    -- vim.api.nvim_buf_delete(buf, { force = true })
  end

  local what = { f('rfc'), f('std'), f('bcp'), f('ien', false), f('fyi', false) }
  local col = (vim.o.columns - 30) / 2
  local row = (vim.o.lines - 5) / 2
  local win_cfg = {
    relative = 'editor',
    width = 30,
    height = 5,
    style = 'minimal',
    row = row,
    col = col,
    title = { { 'Select a series', 'Constant' } },
    footer = { { 'tab toggles selection', 'Keyword' } },
    footer_pos = 'right',
    noautocmd = true,
    border = 'rounded', -- rounded is the default
  }
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_option_value('buftype', 'nofile', { scope = 'local', buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { scope = 'local', buf = buf })
  vim.api.nvim_set_option_value('swapfile', false, { scope = 'local', buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, what)
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close!<cr>', {})
  vim.api.nvim_buf_set_keymap(buf, 'n', '<tab>', '', { callback = toggle })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<enter>', '', { callback = enter })

  local ns_id = vim.api.nvim_create_namespace('pdh.rfc')
  vim.api.nvim_buf_set_extmark(buf, ns_id, 1, 1, { end_line = 1, end_col = 2, hl_group = 'Character' })
  vim.api.nvim_buf_set_extmark(buf, ns_id, 2, 1, { end_line = 2, end_col = 2, hl_group = 'Character' })
  vim.api.nvim_buf_set_extmark(buf, ns_id, 3, 1, { end_line = 3, end_col = 2, hl_group = 'Float' })

  vim.api.nvim_open_win(buf, true, win_cfg)
end

function M.snacky()
  -- popup using snacks.win
  -- todo:
  --  * attach { {option, value}, ..} to buffer, entries are displayed in window
  --  * use format func to display the entries: no need to parse lines afterwards
  local function f(t, on)
    local state = on == nil and H.on or on and H.on or H.off
    return (' %s  %s %s'):format(state, H.sep, t)
  end

  local cycles = {
    series = { H.on, H.off },
    document = { Itms.ICONS[true], Itms.ICONS[false] },
  }
  local function c_next(t, v)
    -- return next index n t for given v
    local max = #t
    for idx, val in ipairs(t) do
      if v == val then
        -- cycle back to first entry if needed
        return t[idx < max and idx + 1 or 1]
      end
    end
    return nil
  end

  local function toggle(obj)
    -- print(vim.inspect(obj))
    local lnr = vim.api.nvim_win_get_cursor(obj.win)[1]
    local line = obj:line(lnr)
    local old = line:match(H.on) or line:match(H.off) -- find frst on/off icon
    local new = c_next(cycles.series, old) -- find its successor
    if new then
      line = line:gsub(old, new)
      vim.api.nvim_set_option_value('modifiable', true, { buf = obj.buf })
      vim.api.nvim_buf_set_lines(obj.buf, lnr - 1, lnr, false, { line })
      vim.api.nvim_set_option_value('modifiable', false, { buf = obj.buf })
    end
  end

  local icon2state = { [H.on] = true, [H.off] = false } -- TODO move to H(elper)
  local function confirm(obj)
    -- parse obj lines (ICON|series) into table<series,boolean>
    local series = {}
    for _, line in ipairs(obj:lines()) do
      local parts = vim.split(line, H.sep, { plain = true, trimempty = true })
      local icon, item = unpack(vim.tbl_map(vim.trim, parts))

      if H.FNAME_PATTERNS[item] then
        series[item] = icon2state[icon]
      end
    end
    obj:close()
    print(vim.inspect({ 'confirm', series }))
  end

  local m = snacks.win({
    -- snacks.win options, hit <space>H when on an option, or:
    -- * `:h snacks-win-config`
    -- * `:h vim.wo` and `:h vim.bo`
    -- * `:h option-list`, and `:h option-summary`
    -- * `:h nvim_open_win`
    -- * `:h special-buffers`
    wo = {
      -- override `:h snacks-win-styles-minimal` options
      cursorline = true, --
      listchars = '',
    },
    bo = {
      modifiable = false,
    },
    fixbuf = true,
    noautocommands = true,
    style = 'minimal', -- see `:h snacks-win-styles-minimal`
    title = { { 'Select series', 'Constant' } },
    footer = { { '?:keymap', 'Keyword' } },
    footer_pos = 'right',
    border = 'rounded',
    text = { f('rfc'), f('std'), f('bcp'), f('fyi', false), f('ien', false) },
    height = 5,
    width = 14,
    keys = {
      ['<space>'] = { toggle, desc = 'toggle' },
      ['<esc>'] = 'close',
      ['?'] = 'toggle_help',
      ['<enter>'] = { confirm, desc = 'accept' },
    },
  })

  -- add highlight for on/off icons
  vim.api.nvim_win_call(m.win, function()
    vim.fn.matchadd('Special', H.off)
    vim.fn.matchadd('Special', H.on)
  end)

  -- print(vim.inspect(m))
end

--- local funcs for new way of curl/read'ing items ---
------------------------------------------------------

---@param doctype doctype
---@param docid string
---@param ext string
---@return string[] lines a, possibly empty, list of strings
local function download(doctype, docid, ext)
  -- returns (possibly empty) list of body lines
  local series = docid:match('^%D+'):lower()
  local url = H.url(doctype, series, ext)
  local accept = Itms.ACCEPT[ext]
  local ok, rv = pcall(plenary.curl.get, { url = url, accept = accept })

  if ok and rv and rv.status == 200 then
    return vim.split(rv.body, '[\r\n\f]', { trimempty = false })
  else
    vim.notify(('[warn] download failed: [%s] %s'):format(rv.status, vim.inspect(url)), vim.log.levels.ERROR)
    return {}
  end
end

local function read_items(fname)
  -- read data file and return list of items or nil,err
  -- local ttl = (M.config.ttl or 0) + vim.fn.getftime(fname) - vim.fn.localtime()
  local t, err = loadfile(fname, 'bt')
  if t then
    return t()
  else
    vim.print(vim.inspect({ 'error', err }))
    return nil, err
  end
end

local function save_items(fname, items)
  -- save to items to file such that it can be read by read_items
  -- returns 0 on success, -1 on failure
  local lines = { '-- autogenerated by rfc.lua, do not edit', '', 'return {' }
  for _, item in ipairs(items) do
    -- vim.inspect inserts \0's, must use %c to replace ('\0' doesn't work(?)
    lines[#lines + 1] = vim.inspect(item):gsub('%c%s*', ' ') .. ','
  end
  lines[#lines + 1] = '}'

  return vim.fn.writefile(lines, fname)
end

local function curl_items(series)
  -- download & parse items for an rfc,std,bcp,ien or fyi index
  series = series:lower()
  local errata = {}
  for _, id in ipairs(download('errata_index', series, 'txt')) do
    errata[('%s%d'):format(series, id)] = 'yes'
  end

  local parse_item = function(accumulated)
    -- parse an accumulated line "nr text" into an item
    local nr, title = accumulated:match('^(%d+)%s+(.*)')
    if nr == nil then
      return nil -- prevents adding botched items to final list
    end

    local docid = ('%s%d'):format(series, nr)
    local item = {
      score = 50,
      text = title, -- we'll extract tags later
      title = ('%s%s'):format(series, nr):upper(), -- used by snack as preview win title
      -- extra fields to search on using > field:term in search prompt
      errata = errata[docid] or 'no',
      docid = docid,
      name = docid:upper(),
      series = series,
    }
    local tags = { -- defined separately in order to filter on ()-constructs
      obsoletes = 'n/a',
      obsoleted_by = 'n/a',
      updates = 'n/a',
      updated_by = 'n/a',
      also = 'n/a',
      status = 'n/a',
      format = '', -- empty string means no format(s) listed/found
      doi = 'n/a',
      authors = 'n/a',
      date = 'n/a',
    }
    item = vim.tbl_extend('error', item, tags) -- ensure tags are present and unique in item

    -- TAGS from 'text', consume the known ()-constructs
    -- TODO: bcp9 (Format: bytes) is not pickup on, still in item.text
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

    -- fix item.formats value (keep only the known ext labels, if any)
    local seen = {}
    for _, fmt in ipairs(Itms.FORMATS) do
      if item.format:match(fmt) then
        seen[#seen + 1] = fmt
      end
    end
    if #seen > 0 then
      item.format = table.concat(seen, ', ')
    end

    -- extract date
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

    -- set file? field to first file found for this docid (if any)
    for _, ext in ipairs(Itms.FORMATS) do
      local fname = H.fname('document', item.docid, ext)
      if fname and vim.fn.filereadable(fname) == 1 then
        item.file = fname
        break
      end
    end
    return item
  end

  -- download and parse the index of items for series
  local input = download('index', series, 'txt')
  local items = {}

  -- assemble lines per item and parse to an item
  local acc = '' -- accumulator, becomes 'nr text'/document, to be parsed as item
  local max = series == 'ien' and 3 or 1 -- allow for leading ws in ien index
  for _, line in ipairs(input) do
    local start = string.match(line, '^(%s*)%d+%s+%S')
    if start and #start < max then
      -- starter line: parse current, start new
      items[#items + 1] = parse_item(acc)
      acc = vim.trim(line) -- trim leading ws(!) for parse()
    elseif #acc > 0 and string.match(line, '^%s+%S') then
      -- continuation line: accumulate
      acc = acc .. ' ' .. vim.trim(line)
    elseif #acc > 0 then
      -- neither a starter, nor continuation: parse current, restart
      items[#items + 1] = parse_item(acc)
      acc = ''
    end
  end
  -- don't forget the last entry
  items[#items + 1] = parse_item(acc)

  return items
end

function M.head()
  -- test checking if file changed remotely
  -- saved items in the form of "return { {...}, {...} ..}, so loadfile
  local fname = H.fname('index', 'rfc', 'lua.dta')

  -- load items from index lua data file
  local items, err = read_items(fname)
  if err then
    vim.notify('error reading items:' .. err)
  end

  -- save items to file in lua data format that is loadfile'able
  if save_items(fname, items) ~= 0 then
    print('error saving items to ' .. fname)
  end

  -- testing download
  local itemz = curl_items('rfc')
  print(vim.inspect({ #itemz, itemz }))
end

vim.keymap.set('n', '<space>r', ":lua require'pdh.rfc'.reload()<cr>")

return M
