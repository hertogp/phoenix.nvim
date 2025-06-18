--[[

# Error handling:

## lua-result-or-message
Lua functions may throw lua-errors for exceptional (unexpected) failures, which you can handle with pcall().
When failure is normal and expected, it's idiomatic to return nil which signals to the caller that failure is
not "exceptional" and must be handled. This "result-or-message" pattern is expressed as the multi-value return
type any|nil,nil|string, or in LuaLS notation:

    ---@return any|nil    # result on success, nil on failure.
    ---@return nil|string # nil on success, error message on failure.

Guidance: use the "result-or-message" pattern for...
- Functions where failure is expected, especially when communicating with the external world.
   E.g. HTTP requests or LSP requests often fail because of server problems, even if the caller did everything right.
- Functions that return a value, e.g. Foo:new().
- When there is a list of known error codes which can be returned as a third value (like luv-error-handling).

## LIB.UV functions:
1) A failing luv function will return to the caller an assertable nil, err, name tuple:
- nil idiomatically indicates failure
- err is a string with the format {name}: {message}
  * {name} is the error name provided internally by uv_err_name
  * {message} is a human-readable message provided internally by uv_strerror
- name is the same string used to construct err

This tuple is referred to below as the *fail pseudo-type*.

2) When a function is called successfully, it will return either:
- a value that is relevant to the operation of the function, or
- the integer 0 to indicate success, or
- sometimes nothing at all.
These cases are documented below.


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

--[[ ALIAS ]]

---@alias series "rfc" | "bcp" | "std" | "fyi" | "ien"
---@alias doctype 'document'|'index'|'errata_index' Last one is rfc specific
---@alias urltype 'document'|'index'|'errata_index'|'errata'|'info' Last three are rfc specific

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

-- function M.select()
--   local choices = Itms.FORMATS
--   for idx, v in ipairs(choices) do
--     v = v .. '|' .. ' ' .. H.fname('document', 'rfc123', v)
--     choices[idx] = v
--   end
--   vim.ui.select(choices, {
--     prompt = 'Select extension to download',
--   }, function(choice)
--     if choice == nil then
--       choice = 'cancelled'
--     end
--   end)
-- end
--
-- function M.snacky()
--   -- popup using snacks.win
--   -- todo:
--   --  * attach { {option, value}, ..} to buffer, entries are displayed in window
--   --  * use format func to display the entries: no need to parse lines afterwards
--   local function f(t, on)
--     local state = on == nil and H.on or on and H.on or H.off
--     return (' %s  %s %s'):format(state, H.sep, t)
--   end
--
--   local cycles = {
--     series = { H.on, H.off },
--     document = { Itms.ICONS[true], Itms.ICONS[false] },
--   }
--   local function c_next(t, v)
--     -- return next index n t for given v
--     local max = #t
--     for idx, val in ipairs(t) do
--       if v == val then
--         -- cycle back to first entry if needed
--         return t[idx < max and idx + 1 or 1]
--       end
--     end
--     return nil
--   end
--
--   local function toggle(obj)
--     -- print(vim.inspect(obj))
--     local lnr = vim.api.nvim_win_get_cursor(obj.win)[1]
--     local line = obj:line(lnr)
--     local old = line:match(H.on) or line:match(H.off) -- find frst on/off icon
--     local new = c_next(cycles.series, old) -- find its successor
--     if new then
--       line = line:gsub(old, new)
--       vim.api.nvim_set_option_value('modifiable', true, { buf = obj.buf })
--       vim.api.nvim_buf_set_lines(obj.buf, lnr - 1, lnr, false, { line })
--       vim.api.nvim_set_option_value('modifiable', false, { buf = obj.buf })
--     end
--   end
--
--   local icon2state = { [H.on] = true, [H.off] = false } -- TODO move to H(elper)
--   local function confirm(obj)
--     -- parse obj lines (ICON|series) into table<series,boolean>
--     local series = {}
--     for _, line in ipairs(obj:lines()) do
--       local parts = vim.split(line, H.sep, { plain = true, trimempty = true })
--       local icon, item = unpack(vim.tbl_map(vim.trim, parts))
--
--       if H.FNAME_PATTERNS[item] then
--         series[item] = icon2state[icon]
--       end
--     end
--     obj:close()
--     print(vim.inspect({ 'confirm', series }))
--   end
--
--   local m = snacks.win({
--     -- snacks.win options, hit <space>H when on an option, or:
--     -- * `:h snacks-win-config`
--     -- * `:h vim.wo` and `:h vim.bo`
--     -- * `:h option-list`, and `:h option-summary`
--     -- * `:h nvim_open_win`
--     -- * `:h special-buffers`
--     wo = {
--       -- override `:h snacks-win-styles-minimal` options
--       cursorline = true, --
--       listchars = '',
--     },
--     bo = {
--       modifiable = false,
--     },
--     fixbuf = true,
--     noautocommands = true,
--     style = 'minimal', -- see `:h snacks-win-styles-minimal`
--     title = { { 'Select series', 'Constant' } },
--     footer = { { '?:keymap', 'Keyword' } },
--     footer_pos = 'right',
--     border = 'rounded',
--     text = { f('rfc'), f('std'), f('bcp'), f('fyi', false), f('ien', false) },
--     height = 5,
--     width = 14,
--     keys = {
--       ['<space>'] = { toggle, desc = 'toggle' },
--       ['<esc>'] = 'close',
--       ['?'] = 'toggle_help',
--       ['<enter>'] = { confirm, desc = 'accept' },
--     },
--   })
--
--   -- add highlight for on/off icons
--   vim.api.nvim_win_call(m.win, function()
--     vim.fn.matchadd('Special', H.off)
--     vim.fn.matchadd('Special', H.on)
--   end)
--
--   -- print(vim.inspect(m))
-- end

--[[ Module ]]

local R = {}
local C = {
  -- config
  cache = vim.fn.stdpath('cache'), -- store item index files
  data = vim.fn.stdpath('data'), -- path or markers
  subdir = 'ietf.org',
  ttl = 4 * 3600, -- time-to-live [second], before downloading again
  edit = 'tabedit ',
  filetype = {
    -- files openen with `edit` may have their ft set
    txt = 'rfc',
  },
  sep = '│',
  on = '●', --- ',  ,  , 
  off = '○', -- ',  ,  ,  ,
}
--- local funcs for new way of curl/read'ing items ---
------------------------------------------------------
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
  pdf = 'applicaiton/pdf',
  ps = 'applicaiton/ps',
}
local ICONS = {
  -- NOTE: add a space after the icon (it is used as-is here)
  [false] = ' ',
  [true] = ' ',
}

local FORMATS = { -- order is important: first one available (disk/net) is used
  -- see: `:!open https://www.rfc-editor.org/rpc/wiki/doku.php?id=rfc_files_available`
  'txt', -- available for all
  'html', -- available for all and only format for rfc/inline-errata
  'xml', -- available from rfc8650 and onwards
  'pdf',
  'ps', -- a few rfc's are available only in postscript
}

--- find root dir or use cfg.top, fallback to stdpath data dir
---@param spec string|table a top dir relative to Rfc-root dir or list root dir markers, eg. {'.git'}
---@return string path full path to rfc-top directory (/rfc-root/rfc-top) (or go bust)
local function get_dir(spec)
  local path

  if type(spec) == 'table' then
    -- find root dir based on markers in cfg.data
    path = vim.fs.root(0, spec)
  elseif type(spec) == 'string' then
    path = vim.fs.normalize(spec)
  end

  return assert(path, ('invalid directory specification %s'):format(vim.inspect(spec)))
end

---get local filename for given `doctype`, `docid` and `ext`
---@param doctype doctype type of document (index, document, info, ..)
---@param docid string unique document name (<series><nr>)
---@param ext string file extension
---@return string path full file path for doc-type and docid or bust!
local function get_fname(doctype, docid, ext)
  local series = docid:match('%D+'):lower()
  local fname_parts = {
    cache = get_dir(C.cache),
    data = get_dir(C.data),
    series = series,
    docid = docid,
    subdir = C.subdir,
    ext = ext,
  }

  assert(PATTERNS.file[series], ('[error] unknown series `%s`'):format(series))
  assert(PATTERNS.file[series][doctype], ('[error] doctype `%s` not valid for series `%s`'):format(doctype, series))
  return PATTERNS.file[series][doctype]:gsub('<(.-)>', fname_parts)
end

---get the rfc-editor document url for given `urltype`, `docid` and `ext`
---@param urltype urltype type of document (index, document, errata, info or errata_index)
---@param docid string unique document name (<series><nr>) within a (sub)series
---@param ext string
---@return string|nil url the url for given `docid` and `ext`
local function get_url(urltype, docid, ext)
  local series = docid:match('^%D+'):lower()
  local url_parts = {
    base = 'https://www.rfc-editor.org',
    docid = docid,
    series = series,
    ext = ext,
  }
  assert(PATTERNS.url[series], ('[error] unknown series `%s`'):format(series))
  assert(PATTERNS.url[series][urltype], ('[error] urltype `%s` not valid for series `%s`'):format(urltype, series))
  return PATTERNS.url[series][urltype]:gsub('<(.-)>', url_parts) -- '<(%S+)> won't work?
end

---download a file, possibly save to disk and return lines, filename? or nil, err
---@param doctype doctype
---@param docid string
---@param ext string
---@param opts? table use save=true to also save download to disk
---@return string[]|nil lines of the file or nil on error
---@return string|nil msg either filename or an err msg
local function download(doctype, docid, ext, opts)
  -- TODO: only return lines for ext=txt, others just save as requested
  opts = opts or {}
  local series = docid:match('^%D+'):lower()
  local url = get_url(doctype, docid, ext)
  local ok, rv
  -- save   txt?
  -- yes    yes -> curl to lines and save lines to file
  -- yes    no  -> curl to file, return {}, fname
  -- no     yes -> curl to lines and return lines
  -- no     no  -> fail

  if ('pdf ps'):match(ext) then
    -- cannot parse these for lines
    if opts.save then
      local fname = get_fname(doctype, docid, ext)
      ok, rv = pcall(plenary.curl.get, { url = url, accept = ACCEPT[ext], output = fname })
      if not ok then
        return nil, rv
      else
        return {}, fname
      end
    else
      return nil, ('cannot parse %s.%s, only download it to file'):format(docid, ext)
    end
  else
    -- others can be parsed as lines
    ok, rv = pcall(plenary.curl.get, { url = url, accept = ACCEPT[ext] })

    if ok and rv and rv.status == 200 then
      local fname = nil
      local lines = vim.split(rv.body, '[\r\n\f]', { trimempty = false })
      if opts.save then
        fname = get_fname(doctype, docid, ext)
        if vim.fn.writefile(lines, fname) == -1 then
          fname = nil
        end
      end
      return lines, fname
    else
      return nil, ('[error] %s: %s'):format(rv.status, url)
    end
  end
end

----read items from `fname` for given `series`
---@param fname string file to get items from
---@param items table a list of picker items
---@return number|nil count items added to given `items` or nil on error
---@return string|nil err message on why call failed, if applicable
local function read_items(fname, items)
  local org = #items
  local t, err = loadfile(fname, 'bt')

  if t == nil or err then
    return nil, err
  end

  for _, item in ipairs(t()) do
    item.idx = #items + 1 -- position of item in items
    items[#items + 1] = item
  end
  return #items - org, nil
end

---@param items table a list of picker items
---@param fname string path to use for saving items
---@return number result 0 if succesful, -1 upon failure
local function save_items(items, fname)
  local lines = { '-- autogenerated by rfc.lua, do not edit', '', 'return {' }
  for _, item in ipairs(items) do
    -- vim.inspect inserts \0's, use %c to replace it since '\0' doesn't work(?)
    lines[#lines + 1] = vim.inspect(item):gsub('%c%s*', ' ') .. ','
  end
  lines[#lines + 1] = '}'

  return vim.fn.writefile(lines, fname)
end

---get items from the series' index at the rfc-editor website
---@param series series
---@param accumulator? table
---@return number|nil count of items added to given `items` or nil on failure
---@return string|nil err message why call failed, if applicable
local function curl_items(series, accumulator)
  -- after retrieving the items from the net, always save to local file
  accumulator = accumulator or {}
  local items = {}
  series = series:lower()

  -- locals
  local errata = {}
  if series == 'rfc' then
    -- only the rfc series actually has an errata index
    for _, id in ipairs(download('errata_index', series, 'txt', { save = true }) or {}) do
      errata[('%s%d'):format(series, id)] = 'yes'
    end
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
    for _, fmt in ipairs(FORMATS) do
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
  local input, err = download('index', series, 'txt')
  if input == nil or err then
    return nil, err -- fail for this series
  end

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

  -- save items to file
  local fname = get_fname('index', series, 'txt')
  save_items(items, fname)

  -- add the items to the accumulator
  for _, item in ipairs(items) do
    accumulator[#accumulator + 1] = item
  end

  return #items, nil
end

---@param series series[]
---@param items table
---@return number|nil amount of items added to `items` for given series
---@return string|nil err message why call failed, if applicable
local function load_items(series, items)
  --local ttl = (M.config.ttl or 0) + ftime - vim.fn.localtime()
  local org_count = #items
  series = series or {}
  if type(series) == 'string' then
    series = { series }
  end

  for _, serie in ipairs(series) do
    local fname = get_fname('index', serie, 'txt')
    local ttl = (C.ttl or 0) + vim.fn.getftime(fname) - vim.fn.localtime()
    local added
    if ttl < 1 then
      added = curl_items(serie, items) or read_items(fname, items) or 0
    else
      added = read_items(serie, items) or curl_items(serie, items) or 0
    end
    vim.notify(('added %d items for series %s'):format(added, serie), vim.log.levels.INFO)
  end
  return #items - org_count
end

---@param item table
---@return table[] parts of the line to display in results list window for `item`
local function item_format(item)
  -- format an item to display in picker list
  -- `:!open https://github.com/folke/snacks.nvim/blob/main/lua/snacks/picker/format.lua`
  local exists = item.file and true or false -- (vim.fn.filereadable(item.file) == 1)
  local icon = ICONS[exists]
  local hl_item = (exists and 'SnacksPickerGitStatusAdded') or 'SnacksPickerGitStatusUntracked'
  local name = ('%-' .. (3 + #(tostring(#R))) .. 's'):format(item.name)
  local ret = {
    { icon, hl_item },
    { C.sep, 'SnacksWinKeySep' },
    { name, hl_item },
    { C.sep, 'SnacksWinKeySep' },
    { item.text, '' },
    { ' ' .. item.date, 'SnacksWinKeySep' },
  }

  return ret
end

--- returns `title`, `ft`, `lines` for use in a preview
--- (used when no local file is present to be previewd)
---@param item table An item of the picker result list
---@return string title The title for an item
---@return string ft The filetype to use when previewing
---@return string[] lines The lines to display when previewing
local function item_details(item)
  -- called when item not locally available
  local title = tostring(item.title)
  local ft = 'markdown'
  -- local cache = vim.fs.joinpath(vim.fn.fnamemodify(M.config.cache, ':p:~:.'), M.config.top, '/')
  -- local data = vim.fs.joinpath(vim.fn.fnamemodify(M.config.data, ':p:~:.'), M.config.top, '/')
  local cache = vim.fs.joinpath(C.cache, C.subdir, '/')
  local data = vim.fs.joinpath(C.data, C.subdir, '/')
  local file = item.file or '*n/a*'
  local fmt2cols = '   %-15s%s'
  local fmt2path = '   %-15s%s' -- prevent strikethrough's use `%s` (if using ~ in path)
  local url
  local ext = vim.split(item.format, ',%s*')[1] -- for (possible) url
  if #ext == 0 then
    url = get_url('document', item.docid, 'txt') .. ' (*maybe*)'
  else
    url = get_url('document', item.docid, ext)
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
  if ctx.item.file and ctx.item.file:match('%.txt$') then
    -- preview ourselves, since snacks trips over any formfeeds in the txt-file
    -- REVIEW: this reads the file every time, could cache that in _preview?
    local ok, lines = pcall(vim.fn.readfile, ctx.item.file)
    local title, ft

    if not ok then
      -- fallback to preview item itself (ft will be markdown)
      title, ft, lines = item_details(ctx.item)
    else
      title = ctx.item.docid:upper()
      ft = 'rfc' -- since we're looking at the text itself
    end
    _set(ctx, title, lines, ft)
  elseif ctx.item._preview then
    -- we've seen it before, use previously assembled info
    local m = ctx.item._preview
    _set(ctx, m.title, m.lines, m.ft)
  else
    -- use item._preview: since item.preview={text="..", ..} means text will be split every time
    local title, ft, lines = item_details(ctx.item)
    _set(ctx, title, lines, ft)
    ctx.item._preview = { title = title, ft = ft, lines = lines } -- remember for next time
  end
end

local W = {
  list = {
    -- picker list window showing results
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
    -- picker input window where search is typed
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

--- retrieves one or more documents from the rfc-editor
---@param picker table current picker in action
---@param curr_item table the current item in pickers results window
function R.fetch(picker, curr_item)
  -- curr_item == picker.list:current()
  local items = picker.list.selected
  if #items == 0 then
    items = { curr_item }
  end
  local notices = { '# Fetch:\n' }

  for n, item in ipairs(items) do
    for _, ext in ipairs(FORMATS) do
      -- download first available format
      local ok, fname = download('document', item.docid, ext, { save = true })
      if ok and fname then
        item.file = fname
        notices[#notices + 1] = ('- (%d/%s) %s.%s - success'):format(n, #items, item.docid, ext)
        break
      else
        notices[#notices + 1] = ('- (%d/%s) %s.%s - failed!'):format(n, #items, item.docid, ext)
      end
    end

    if item.file then
      item._preview = nil
      picker.list:unselect(item)
      picker.list:update({ force = true })
      picker.preview:show(picker, { force = true })
    end
  end
  vim.notify(table.concat(notices, '\n'), vim.log.levels.INFO)
end

--- sets the preview window contents to a dump of the item table
---@param picker table current picker in action
---@param item table the current item in pickers results window
function R.inspect(picker, item)
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

  picker.preview:reset() -- REVIEW: necessary ?
  picker.preview:set_lines(lines)
  picker.preview:set_title(item.title)
  picker.preview:highlight({ ft = 'markdown' })
end

function R.remove(picker, curr_item)
  -- curr_item == picker.list:current() ?= picker:current()
  -- remove local item.file's for 1 or more items
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
      item.file = nil -- file was not there
    else
      result = 'item.file not set'
    end
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
function R.visit_info(_, item)
  local url = get_url('info', item.docid, 'html')
  if url then
    vim.cmd(('!open %s'):format(url))
  end
end

--- Visits the html page of the current item
---@param _ table
---@param item table the current item at the time of the keypress
function R.visit_page(_, item)
  local url = get_url('document', item.docid, 'html')
  if url then
    vim.cmd(('!open %s'):format(url))
  end
end

--- Visits the errate page (if any) of the current (rfc) item
---@param _ table
---@param item table the current item at the time of the keypress
function R.visit_errata(_, item)
  local url = get_url('errata', item.docid, '')
  if url then
    vim.cmd(('!open %s'):format(url))
  end
end

--- Open the current item, either is neovim (txt) or via `open` for other formats
---@param picker table
---@param item table the current item at the time of the keypress
function R.confirm(picker, item)
  picker:close()
  if not item.file then
    R.fetch(picker, item)
  end

  if item.file and item.file:lower():match('%.txt$') then
    -- edit in nvim
    vim.cmd(C.edit .. ' ' .. item.file)
    local ft = C.filetype['txt']
    if ft then
      vim.cmd('set ft=' .. ft)
    end
  elseif item.file then
    -- TODO: Brave browser can't access .local/data files ..
    vim.cmd('!open ' .. item.file)
  end
end

function R.search(series)
  for ix, _ in ipairs(R) do
    R[ix] = nil
  end

  if load_items(series, R) < 1 then
    vim.notify('[error] no items for series')
  end

  return snacks.picker({
    items = R,

    format = item_format,
    preview = item_preview,
    actions = R,
    confirm = R.confirm,
    win = W,

    layout = { fullscreen = true },
  })
end

return R
