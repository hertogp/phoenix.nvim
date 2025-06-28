--[[

Search, download and read ietf rfc's.
- some entry points
  * `:!open https://www.rfc-editor.org/rfc/rfc-index.txt`
  * `:!open https://www.rfc-editor.org/rfc/rfc-ref.txt`
  * `:!open https://www.rfc-editor.org/rfc/rfc-index.xml` -- rfc<x>.json contains the values as well
    - seems bcp entries are just referring to rfc's via is_also tags ... i.e. different from bcp-index.txt
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

  * also subdirs: rfc/{bcp, std, ien, fyi} with <docid>.ext and series-index.txt

  * terminology:
    - streams - producers of documents: https://www.rfc-editor.org/faq/#streamcat
      Document stream = IETF, IRTF, IAB, Independent
    - Category = (proposed) STD, BCP, Experimental, Informational and Historic (aka status)
    - Series = The RFC series, STD docs are a subseries of the RFC series
      BCP is its own series, like IEN and FYI's
    - Status only applies to RFC's, STD/BCP/IEN/FYI have no status

--]]

--[[ ALIAS ]]

---@alias docid string unique document name {series}{nr} across all series
---@alias series "rfc" | "bcp" | "std" | "fyi" | "ien"
---@alias doctype 'document'|'index'|'errata_index' document types used by the rfc-editor
---@alias urltype 'document'|'index'|'errata_index'|'errata'|'info' Last three are rfc specific

--[[ DEPENDENCIES ]]

---@param name string
---@return any dependency the required dependency
local function dependency(name)
  local ok, var = pcall(require, name)
  assert(ok, ('[error] missing dependency: '):format(name), vim.log.levels.ERROR)
  return var
end
local plenary = dependency('plenary')
local snacks = dependency('snacks')

--[[ LOCALS ]]

local M = {} -- module to be returned

local C = {
  series = { 'rfc', 'std', 'bcp' }, -- series to search
  cache = vim.fn.stdpath('cache'), -- path for rfc-editor index files
  data = vim.fn.stdpath('data'), -- path (or markers), for rfc-editor documents
  subdir = 'rfc-editor', -- plugin subdir under cache and/or data path
  ttl = 24 * 3600, -- ttl in seconds, before downloading again
  edit = {
    -- default is to :Open <fname>
    txt = 'tabedit', -- open txt documents in a new tab
    pdf = 'Open', -- shell out to host system
  },
  filetype = {
    txt = 'rfc', -- set filetype to rfc when opening in nvim
  },
}

local PATTERNS = {
  -- see `:!open https://www.rfc-editor.org/rfc/` for the various documents
  url = {
    rfc = {
      index = '<base>/<series>/<series>-index.<ext>',
      document = '<base>/<series>/<docid>.<ext>',
      errata_index = '<base>/rfc/RFCs_for_errata.<ext>',
      errata = '<base>/errata/<docid>',
      info = '<base>/info/<docid>',
    },
    std = {
      index = '<base>/<series>/<series>-index.<ext>',
      document = '<base>/<series>/<docid>.<ext>',
    },
    bcp = {
      index = '<base>/<series>/<series>-index.<ext>',
      document = '<base>/<series>/<docid>.<ext>',
    },
    ien = {
      index = '<base>/<series>/<series>-index.<ext>',
      document = '<base>/<series>/<docid>.<ext>',
    },
    fyi = {
      index = '<base>/<series>/<series>-index.<ext>',
      document = '<base>/<series>/<docid>.<ext>',
    },
  },
  file = {
    rfc = {
      document = '<data>/<subdir>/<series>/<docid>.<ext>',
      index = '<cache>/<subdir>/<series>-index.<ext>',
      errata_index = '<cache>/<subdir>/<series>-errata.<ext>',
    },
    std = {
      document = '<data>/<subdir>/<series>/<docid>.<ext>',
      index = '<cache>/<subdir>/<series>-index.txt',
    },
    bcp = {
      document = '<data>/<subdir>/<series>/<docid>.<ext>',
      index = '<cache>/<subdir>/<series>-index.txt',
    },
    ien = {
      document = '<data>/<subdir>/<series>/<docid>.<ext>',
      index = '<cache>/<subdir>/<series>-index.txt',
    },
    fyi = {
      document = '<data>/<subdir>/<series>/<docid>.<ext>',
      index = '<cache>/<subdir>/<series>-index.txt',
    },
  },
}

local ACCEPT = {
  -- http header values for accept
  txt = 'text/plain',
  html = 'text/html',
  xml = 'application/xml',
  pdf = 'application/pdf',
  ps = 'application/ps',
}
local ICONS = {
  -- used to denote if a file exists locally (true) or not (false)
  file = {
    missing = ' ',
    present = ' ',
  },
  -- on = '●', --- ',  ,  , 
  -- off = '○', -- ',  ,  ,  ,
}

local FORMATS = {
  -- order is used to find first one available (disk/net)
  -- see: `:!open https://www.rfc-editor.org/rpc/wiki/doku.php?id=rfc_files_available`
  'txt',
  'html',
  'xml',
  'pdf',
  'ps',
}

--[[ HELPERS ]]

--- get normalized path for given `path_spec`, raises on error
---@param path_spec string|table a path or list of directory markers
---@return string path full path to a directory (/rfc-root/rfc-top)
local function get_dir(path_spec)
  local path

  if type(path_spec) == 'table' then
    -- find root dir based on markers in cfg.data
    path = vim.fs.root(0, path_spec)
  elseif type(path_spec) == 'string' then
    path = vim.fs.normalize(path_spec)
  end
  print(vim.inspect({ 'isdir', path, vim.fn.isdirectory(path or '') }))

  assert(path, ('invalid directory: %s'):format(vim.inspect(path_spec)))
  assert(vim.fn.isdirectory(path) == 1, ('[error] not a directory: %s'):format(vim.inspect(path)))
  return path
end

---get local filename for given `doctype`, `docid` and `ext`, raises on error
---@param doctype doctype type of document (index, document, info, ..)
---@param docid string unique document name (<series><nr>)
---@param ext string file extension
---@return string path full file path for doc-type and docid
local function get_fname(doctype, docid, ext)
  local series = docid:match('%D+'):lower()
  local fname_parts = {
    cache = C.cache,
    data = C.data,
    series = series,
    docid = docid,
    subdir = C.subdir,
    ext = ext,
  }

  --TODO: may return url, nil | nil, err just like get_url?

  assert(PATTERNS.file[series], ('[error] unknown series `%s`'):format(series))
  assert(PATTERNS.file[series][doctype], ('[error] doctype `%s` not valid for series `%s`'):format(doctype, series))
  return PATTERNS.file[series][doctype]:gsub('<(.-)>', fname_parts)
end

---get the rfc-editor document url for given `urltype`, `docid` and `ext`
---@param urltype urltype type of document (index, document, errata, info or errata_index)
---@param docid docid unique document name (<series><nr>) within a series
---@param ext string file extension to use when downloading
---@return string|nil url the url for given `docid` and `ext`, nil on error
---@return string|nil err message or nil on success
local function get_url(urltype, docid, ext)
  local series = docid:match('^%D+'):lower()
  local url_parts = {
    base = 'https://www.rfc-editor.org',
    docid = docid,
    series = series,
    ext = ext,
  }
  if PATTERNS.url[series] then
    if PATTERNS.url[series][urltype] then
      return PATTERNS.url[series][urltype]:gsub('<(.-)>', url_parts), nil -- '<(%S+)> won't work?
    else
      return nil, ('invalid urltype `%s`'):format(vim.inspect(urltype))
    end
  else
    return nil, ('invalid series `%s`'):format(vim.inspect(series))
  end
end

---download a file and save to disk, returns body lines only for txt files, nil on error
---@param doctype doctype type of rfc-editor document
---@param docid string unique document name (<series><nr>)
---@param ext string file extension
---@param opts? table use `{save=true}` for txt files, to also save it to disk
---@return string[]|nil lines of the file (empty, except for txt files) or nil on error
---@return string|nil msg the download filename or an err msg
local function get_doc(doctype, docid, ext, opts)
  -- NOTE:
  -- 1) compressed=false was added to avoid curl timeout (doesn't understand encoding type).
  --    see: `:!open https://community.cloudflare.com/t/r2-not-removing-aws-chunked-from-content-encoding/786494/3`
  --    docs are served by aws servers, content-encoding=aws-chunked used for upload, which is AWS specific
  --    and appears as content-encoding type in the response header when curl'ing an rfc (since 2025-06-16 or so)
  -- 2) document test cases:
  --   * rfc14 will be not found (only .json exists)
  --   * ien15.pdf (only format available)
  opts = opts or {}
  local url, err = get_url(doctype, docid, ext)
  local rv, fname

  if err then
    return nil, err
  end

  if ext == 'txt' then
    rv = plenary.curl.get({ url = url, compressed = false, accept = ACCEPT[ext] })

    if rv and rv.status == 200 then
      fname = nil
      local lines = vim.split(rv.body, '[\r\n\f]', { trimempty = false })
      if opts.save then
        fname = get_fname(doctype, docid, ext)
        fname = vim.fn.writefile(lines, fname) == 0 and fname or nil
      end
      return lines, fname
    elseif rv then
      return nil, ('[error] %s: %s'):format(rv.status, url)
    else
      return nil, ('[error] timeout? %s'):format(url)
    end
  else
    fname = get_fname(doctype, docid, ext)
    rv = plenary.curl.get({ url = url, compressed = false, accept = ACCEPT[ext], output = fname })
    if rv and rv.status == 200 then
      return {}, fname -- list of lines is empty since it was saved to disk
    else
      vim.fn.delete(fname) -- remove 404 pages and the like, file content is not a valid document
      return nil, ('[error] %s: %s'):format(rv.status, url)
    end
  end
end

--[[ ITEM handlers ]]

--- add items to the accumulator `items`, as read from the cached index file `fname`
---@param fname string filename of index file to get items
---@param items table a list of picker items
---@return number|nil count items added to given `items` or nil on error
---@return string|nil err nil on success, error message otherwise
local function read_items(fname, items)
  local org = #items
  local t, err = loadfile(fname, 'bt')

  if t == nil or err then
    return nil, err
  end

  for _, item in ipairs(t()) do
    -- set file? field to first file found for this docid (if any)
    item.file = nil -- no file found (yet)
    for _, ext in ipairs(FORMATS) do
      local file = get_fname('document', item.docid, ext)
      if file and vim.fn.filereadable(file) == 1 then
        item.file = file
        break
      end
    end
    item.idx = #items + 1 -- position of item in items
    items[#items + 1] = item
  end
  return #items - org, nil
end

--- save items to an index file on disk, items should belong to only 1 series
---@param items table a list of picker items
---@param fname string path to use for saving items
---@return number result 0 if successful, -1 upon failure
local function save_items(items, fname)
  -- saving items as a list, instead of a table: yields a 2.4MB file instead of 3.9MB
  -- at the cost of slightly more word for read_items()
  local lines = { '-- autogenerated (rfc.lua), do not edit', '', 'return {' }
  for _, item in ipairs(items) do
    -- temporarily remove fields not part of the index information
    local file, idx = item.file, item.idx
    item.file, item.idx = nil, nil

    -- inspect may add '\0' for multiline output, %z matches \0, %c all control chars
    lines[#lines + 1] = vim.inspect(item):gsub('%c%s*', ' ') .. ',' -- works, but dodgy

    item.file, item.idx = file, idx
  end
  lines[#lines + 1] = '}'

  return vim.fn.writefile(lines, fname)
end

---add items to the accumulator (and cache) from the remote rfc-editor index for given (single) `series`
---@param series series a single series whose items are retrieved from rfc-editor
---@param accumulator table list of picker items
---@return number|nil count of items added to given `accumulator` or nil on failure
---@return string|nil err message why call failed, if applicable
local function curl_items(series, accumulator)
  -- after retrieving the items from the net, always save to local cache file
  accumulator = accumulator or {}
  local items = {}
  series = series:lower()

  -- load the list of rfc numbers for which errata exist
  local errata = {}
  if series == 'rfc' then
    -- only the rfc series actually has an errata index
    local fname = get_fname('errata_index', 'rfc', 'txt')
    local ttl = C.ttl + vim.fn.getftime(fname) - vim.fn.localtime()
    local lines = {}

    if ttl < 1 then
      lines = get_doc('errata_index', series, 'txt', { save = true }) or vim.fn.readfile(fname)
    else
      lines = vim.fn.readfile(fname)
      if #lines == 0 then
        lines = get_doc('errata_index', series, 'txt', { save = true }) or {}
      end
    end

    for _, id in ipairs(lines) do
      -- track which docid's have errata
      errata[('%s%d'):format(series, id)] = 'yes'
    end
  end

  local parse_item = function(index_line)
    -- parse an accumulated line "nr text" into an item
    local nr, title = index_line:match('^(%d+)%s+(.*)')
    if nr == nil then
      return nil -- prevents adding botched items to the accumulator
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
    local tags = { -- defined separately in order to filter on ()-constructs found in doc-title text
      obsoletes = 'n/a',
      obsoleted_by = 'n/a',
      updates = 'n/a',
      updated_by = 'n/a',
      also = 'n/a',
      status = 'n/a',
      format = '', -- none found (yet)
      doi = 'n/a',
      authors = 'n/a',
      date = 'n/a',
    }
    item = vim.tbl_extend('error', item, tags) -- ensure tags are present and unique in item

    -- get TAGS from 'text', consume the known ()-constructs
    for part in string.gmatch(item.text, '%(([^)]+)%)') do
      -- lowercase so we can match on keys in tags
      local prepped = part:lower():gsub('%s+by%s', '_by ', 1):gsub(':', '', 1)
      local k, v = string.match(prepped, '^([^%s]+)%s+(.*)$')
      if k and v and tags[k] then
        item[k] = v
        -- remove matched `part` from doc-title text
        item.text = string.gsub(item.text, '%s?%(' .. part .. '%)', '', 1)
      end
    end

    -- fix item.formats value (keep only the known ext labels, if any)
    local seen = {}
    for _, fmt in ipairs(FORMATS) do
      if item.format:match(fmt) then
        seen[#seen + 1] = fmt
      end
    end
    item.format = '' -- ditch the garbage
    if #seen > 0 then
      item.format = table.concat(seen, ', ') -- keep what was seen
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
    for _, ext in ipairs(FORMATS) do
      local fname = get_fname('document', item.docid, ext)
      if fname and vim.fn.filereadable(fname) == 1 then
        item.file = fname
        break
      end
    end
    return item
  end

  -- download and parse the index of items for series
  local input, err = get_doc('index', series, 'txt')
  if input == nil or err then
    return nil, err -- fail for this series
  end

  -- assemble lines per item and parse to an item
  local acc = '' -- accumulator, becomes 'nr text'/document, to be parsed as item
  local max = series == 'ien' and 3 or 1 -- allow for leading wspace in ien index
  for _, line in ipairs(input) do
    local start = string.match(line, '^(%s*)%d+%s+%S')
    if start and #start < max then
      -- starter line: parse current, start new
      items[#items + 1] = parse_item(acc)
      acc = vim.trim(line) -- trim leading wspace(!) for parse()
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

  -- add the items to the accumulator
  -- TODO: add directly to accumulator & calc nr as #accumulator -org_count
  for _, item in ipairs(items) do
    accumulator[#accumulator + 1] = item
  end

  -- save items to file
  local fname = get_fname('index', series, 'txt')
  if save_items(items, fname) == 0 then
    vim.notify(('[info] curl-d %d %s-items, saved to %s'):format(#items, series, fname), vim.log.levels.INFO)
  else
    vim.notify(('[error] curl-d %d %s-items, NOT saved to %s'):format(#items, series, fname), vim.log.levels.ERROR)
  end

  return #items, nil
end

---add cached items from disk for given `series` to `items`
---@param series series[] list of series for which items are to be added
---@param items table receives the items for given `series`
---@return number count of items added to `items` for given `series`
---@return string[]|nil err message(s) on which series failed, if any, nil otherwise
local function load_items(series, items)
  series = series or {}
  if type(series) == 'string' then
    series = { series }
  end

  local count = 0
  local warnings = {}

  for _, serie in ipairs(series) do
    local fname = get_fname('index', serie, 'txt')
    local ttl = C.ttl + vim.fn.getftime(fname) - vim.fn.localtime()
    local cnt, warn

    if ttl < 1 then
      -- read from network, fallback to cache
      cnt, warn = curl_items(serie, items)
      if warn then
        cnt, warn = read_items(fname, items)
      end
    else
      -- read from cache, fallback to network
      cnt, warn = read_items(fname, items)
      if warn then
        cnt, warn = curl_items(serie, items)
      end
    end
    if warn then
      warnings[#warnings + 1] = ('[warn] no items found for %s (%s)'):format(series, warn)
    else
      count = count + cnt
    end
  end

  return count, #warnings > 0 and warnings or nil
end

---returns item info as markdown lines to fill the preview window,
---used when no local file is present or a non-text file
---@param item table an item of the picker result list
---@return string[] lines the lines to display in the preview window
local function item_markdown(item)
  local cache = vim.fs.joinpath(C.cache, C.subdir, '/')
  local data = vim.fs.joinpath(C.data, C.subdir, '/')
  local file = item.file or '*n/a*'
  local errata = item.series == 'rfc' and item.errata or '-'
  local fmt2cols = '   %-15s%s'
  local fmt2path = '   %-15s%s' -- prevent strikethrough's use `%s` (if using ~ in path)
  local url

  local ext = vim.split(item.format, ',%s*')[1] -- for (possible) url
  if #ext == 0 then
    url = get_url('document', item.docid, 'txt') .. ' (*maybe*)'
  else
    url = get_url('document', item.docid, ext)
  end

  return {
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
    fmt2cols:format('ERRATA', errata),
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
end

--[[ SNACKS callbacks ]]

---format function passed to picker to update an item in the result list window
---@param item table the item to display in the list window
---@return table[] parts list of line parts to display { {text, hl_group}, ..}
local function item_format(item)
  -- `:!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/format.lua`
  local sep = '│'
  local icon = item.file and ICONS.file.present or ICONS.file.missing
  local hl_item = (item.file and 'SnacksPickerGitStatusAdded') or 'SnacksPickerGitStatusUntracked'
  local name = ('%-' .. (3 + #(tostring(#M))) .. 's'):format(item.name)
  return {
    { icon, hl_item },
    { sep, 'SnacksWinKeySep' },
    { name, hl_item },
    { sep, 'SnacksWinKeySep' },
    { item.text, '' },
    { ' ' .. item.date, 'SnacksWinKeySep' },
  }
end

---update the preview window, function is passed to the picker
---@param ctx table picker object
local function item_preview(ctx)
  -- called when ctx.item becomes the current one in the results list

  local _set = function(picker, title, lines, ft)
    -- see snacks.picker.core.preview for the preview funcs used below
    picker.preview:reset() -- REVIEW: necessary ?
    picker.preview:set_lines(lines)
    picker.preview:set_title(title)
    picker.preview:highlight({ ft = ft })
  end

  local title = ctx.item.docid:upper()
  local ft = 'rfc' -- assume file contents will be previewed
  local ok, lines

  if ctx.item.file and ctx.item.file:match('%.txt$') then
    -- preview ourselves, since snacks trips over any formfeeds in the txt-file
    -- REVIEW: this reads the file every time, could cache that in _preview?
    ok, lines = pcall(vim.fn.readfile, ctx.item.file)

    if not ok then
      -- fallback to preview item as markdown
      lines = item_markdown(ctx.item)
      ft = 'markdown'
    end
    _set(ctx, title, lines, ft)
  elseif ctx.item._preview then
    -- we've seen it before, use previously assembled info
    local m = ctx.item._preview
    _set(ctx, m.title, m.lines, m.ft)
  else
    -- use item._preview: since item.preview={text="..", ..} means text will be split every time
    lines = item_markdown(ctx.item)
    ft = 'markdown'
    _set(ctx, title, lines, ft)
    ctx.item._preview = { title = title, ft = ft, lines = lines } -- remember for next time
  end
end

--[[ SNACKS keymaps ]]

local W = {
  -- picker win option
  list = {
    -- keybindings for picker list window showing results
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

  input = {
    -- keybindings for picker input window where search is typed
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
}

--[[ Module ]]

---retrieve one or more documents from the rfc-editor, update the item.file field(s)
---@param picker table the current picker
---@param item table the current item in pickers results window
function M.fetch(picker, item)
  -- curr_item == picker.list:current()
  local items = picker.list.selected
  if #items == 0 then
    items = { item }
  end
  local notices = { '# Fetch:\n' }

  for n, itm in ipairs(items) do
    for _, ext in ipairs(FORMATS) do
      -- download first available format
      local ok, fname = get_doc('document', itm.docid, ext, { save = true })
      if ok and fname then
        itm.file = fname
        notices[#notices + 1] = ('- (%d/%s) %s.%s - success'):format(n, #items, itm.docid, ext)
        break
      else
        notices[#notices + 1] = ('- (%d/%s) %s.%s - failed! %s'):format(n, #items, itm.docid, ext, vim.inspect(fname))
      end
    end

    if itm.file then
      itm._preview = nil
      picker.list:unselect(itm)
      picker.list:update({ force = true })
      picker.preview:show(picker, { force = true })
    end
  end
  vim.notify(table.concat(notices, '\n'), vim.log.levels.INFO)
end

---set the preview window contents to a dump of the item table
---@param picker table current picker in action
---@param item table the current item in pickers results window
function M.inspect(picker, item)
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

  --- end
  picker.preview:reset() -- REVIEW: necessary ?
  picker.preview:set_lines(lines)
  picker.preview:set_title(item.title)
  picker.preview:highlight({ ft = 'markdown' })
end

---remove files associated with current item or selection of items
---@param picker table current picker in action
---@param item table the current item in pickers results window
function M.remove(picker, item)
  -- curr_item == picker.list:current() ?= picker:current()
  -- remove local item.file's for 1 or more items
  local items = picker.list.selected
  if #items == 0 then
    items = { item }
  end
  local notices = { '# Remove:\n' }

  for n, itm in ipairs(items) do
    local result
    if itm.file and vim.fn.filereadable(itm.file) == 1 then
      local rv = vim.fn.delete(itm.file)
      if rv == 0 then
        result = 'removed'
        itm.file = nil
      else
        -- keep unreadable item.file
        result = 'failed!'
      end
    elseif itm.file then
      result = 'not found'
      itm.file = nil -- file was not there
    else
      result = 'item.file not set'
    end
    picker.list:unselect(itm) -- whether selected or not ..
    picker.list:update({ force = true })
    picker.preview:show(picker, { force = true })
    notices[#notices + 1] = ('- (%d/%s) %s - %s'):format(n, #items, itm.docid, result)
  end
  vim.notify(table.concat(notices, '\n'), vim.log.levels.INFO)
end

---visit the rfc-editor *info* page of the current item
---@param _ table
---@param item table the current item at the time of the keypress
function M.visit_info(_, item)
  local url = get_url('info', item.docid, 'html')
  if url then
    vim.cmd(('!open %s'):format(url))
  end
end

---visit the ref-editor *html* page of the current item
---@param _ table
---@param item table the current item at the time of the keypress
function M.visit_page(_, item)
  local url = get_url('document', item.docid, 'html')
  if url then
    vim.cmd(('!open %s'):format(url))
  end
end

---visit the rfc-editor *errata* page (if any) of the current (rfc) item
---@param _ table
---@param item table the current item at the time of the keypress
function M.visit_errata(_, item)
  local url = get_url('errata', item.docid, '')
  if url then
    vim.cmd(('!open %s'):format(url))
  end
end

---open the current item, either in neovim (txt) or via `open` for other formats
---@param picker table
---@param item table the current item at the time of the keypress
---@return 0|nil ok  -- 0 for success, nil for error
---@return string|nil err? nil if successful, error message otherwise
function M.confirm(picker, item)
  picker:close()

  if not item.file then
    M.fetch(picker, item)
  end

  if not item.file then
    local msg = ('[error] Could not retrieve %s'):format(item.docid)
    vim.notify(msg, vim.log.levels.ERROR)
    return nil, msg
  end

  local ext = item.file:lower():match('%.([^.]+)$')
  local cmd = C.edit[ext] or 'Open'
  local ft = C.filetype[ext]

  vim.cmd(cmd .. ' ' .. item.file)

  if ft then
    vim.cmd('set ft=' .. ft)
  end
  return 0
end

---search items for given `series`
---@param series series|series[] search a series or list of thereof
function M.search(series)
  -- TODO:
  -- [ ] only remove series not listed in series
  -- [ ] only add series not already present in R
  for ix, _ in ipairs(M) do
    M[ix] = nil
  end

  series = series or C.series
  if type(series) == 'string' then
    series = { series }
  end

  local _, warnings = load_items(series, M)
  if warnings then
    local msgs = table.concat(warnings, '\n- ')
    vim.notify(('# Warning(s)\n- %s'):format(msgs), vim.log.levels.WARN)
  end

  return snacks.picker({
    items = M,
    format = item_format,
    preview = item_preview,
    actions = M,
    confirm = M.confirm,
    win = W,
    layout = { fullscreen = true },
  })
end

---setup and return the configuration
---@param opts? table configuration options with (new) values
---@return table opts the effective configuration after setup
function M.setup(opts)
  if not opts then
    return C
  end

  assert(type(opts) == 'table', ('expected opts (a table), not %s'):format(vim.inspect(opts)))
  local notes = { '# RFC config warnings:' }

  -- C.series
  local series = {}
  for _, serie in ipairs(opts.series or {}) do
    if PATTERNS.url[serie] then
      series[#series + 1] = serie -- PATTERNS.url specifies url's for known `series`
    else
      notes[#notes + 1] = ('- [warn] ignoring unknown type of series `%s`'):format(vim.inspect(serie))
    end
  end
  if #series > 0 then
    C.series = series
  end

  C.cache = opts.cache and get_dir(opts.cache) or C.cache
  C.data = opts.data and get_dir(opts.data) or C.data
  C.subdir = type(opts.subdir) == 'string' and opts.subdir or C.subdir
  C.ttl = type(opts.ttl) == 'number' and opts.ttl or C.ttl

  -- editing commands
  local edit = {}
  for ext, cmd in pairs(opts.edit or {}) do
    if ACCEPT[ext] and type(cmd) == 'string' and (vim.fn.exists(':' .. cmd) == 2 or cmd:match('^!')) then
      -- ACCEPT specifies html headers for all known extensions
      edit[ext] = cmd
    else
      notes[#notes + 1] = ('- [warn] ignoring unknown command `%s` for editing'):format(vim.inspect(cmd))
    end
  end
  if #edit > 0 then
    C.edit = edit
  end

  -- filetypes
  local filetype = {}
  for ext, ft in pairs(opts.filetype or {}) do
    if ACCEPT[ext] and type(ft) == 'string' then
      filetype[ext] = ft
    elseif ACCEPT[ext] then
      notes[#notes + 1] = ('- [warn] ignoring `%s` is not a string for filetype'):format(vim.inspect(ft))
    else
      notes[#notes + 1] = ('- [warn] extension `%s` is not supported'):format(ext, ft)
    end
  end
  if #filetype > 0 then
    C.filetype = filetype
  end

  if #notes > 0 then
    vim.notify(table.concat(notes, '\n'), vim.log.levels.WARN)
  end
  return C
end

return M
