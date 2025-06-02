-- File: ~/.config/nvim/lua/pdh/outline.lua
-- Find outline for various filetypes

--[[
Behaviour
- otl is toggle'd from a buffer in window x:
  * buffer has no b.otl -> create one, note x as otl.swin, select otl window
  * buffer has an b.otl -> close its window, remove b.otl, stay in current window
  * toggle should ignore calls when org window is a floating window
- when shuttle'ing, otl attaches to the win showing sbuf
- swin becomes invisible -> otl is hidden as well
- swin becomes visible   -> otl becomes visible again
- otl becomes invisible  -> otl is destroyed and sbuf.otl is removed and swin is selected

TODO's
[ ] add treesitter scm handler -> ~/config/nvim/queries/<lang>/outline.scm
[ ] add treesitter cst handler -> with config to extract (simply) from treesitter's concrete syntax tree
[?] add lsp sym(bols) handler -> using vim.lsp.buf.document_symbol()
      * also see :FzfLua lsp_document_symbols (aka <space>s)
[?] have only 1 otl window at all times (:topleft vnew | wincmd H | wincmd =)
    - configurable, left or right, always has entire heigt of window
    - multiple windows can have otl active
    - active window is displayed in otl window (shuttle works)
      * when moving to another window that has no otl -> otl stays the same
      * when moving to another windown that has otl -> otl switches association with that window/buffer
 [ ] a spec should be able to defer to another spec via a canonical name
 [ ] a spec should be able to have multiple outline providers, some of which maybe disabled

--]]

--[[ GLOBALS ]]

local M = {}

--[[ HELPERS ]]

local function ts_depth(node, root)
  -- how deep is node relative to root?
  local depth = 0
  local p = node:parent()
  while p and p ~= root do
    depth = depth + 1
    p = p:parent()
  end
  return depth
end

-- match:table<integer,TSNode[]> -> maps captureID's to a list of captured nodes
-- pattern:integer               -> the index of matching pattern in query file
-- source:integer|string         ->  (bufnr) -> source buffer number of name
-- predicate:any[]               -> list of strings of full directive being called:
--                                  here: {"join!", "name", char, id1, id2, ...}
--                                  char is used to join strings from nodes i/t match
-- meta:vim.treesitter.query.TSMetadata
local function joincaptures(match, _, bufnr, predicate, meta)
  -- update meta table: meta[name] = val
  -- P { "predicate", predicate }
  local name = predicate[2] -- usually just "head"
  local val = nil -- accumulates strings from the nodes in the match (id1, .. id<n>)

  if #predicate < 4 then
    -- {"join!", name, "char"}
    for _, node in ipairs(match) do
      local text = vim.treesitter.get_node_text(node, bufnr)
      val = string.gsub(text, '[\n\r].*', '', 1)
    end
  else
    -- ("join!", name, char, id1, id2, ..}
    -- where idx may be a string, in which case its added as-is
    local char = predicate[3] -- used to join text from match[id<x>]
    for i = 4, #predicate do
      local key = predicate[i]
      local text = ''
      -- if key is a number -> get node by number from match
      -- if key is string -> add to value as-is
      if type(key) == 'string' then
        text = key
      else
        local node = match[key]
        text = vim.treesitter.get_node_text(node, bufnr)
        -- P { "key", key, "char", char, "text", text }
      end
      text = string.gsub(text, '[\n\r].*', '', 1)
      val = val and (val .. char .. text) or text
    end
  end
  if val then
    meta[name] = val
  end
  -- return true
end

-- see function above
-- name:string - name of the directive without the leading #
-- handler:function - fun(match, pattern, source, predicate, metadata)
-- opts:table - force:boolean, all:boolean
vim.treesitter.query.add_directive('join!', joincaptures, { force = true })

local function buf_sanitize(buf)
  -- return a real, valid buffer number or nil
  if buf == nil or buf == 0 then
    return vim.api.nvim_get_current_buf()
  elseif vim.api.nvim_buf_is_valid(buf) then
    return buf
  end
  return nil
end

--[[ WINDOW funcs ]]
local W = {}

function W.centerline(win, linenr)
  -- try to keep line in window at same spot
  if vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_set_cursor, win, { linenr, 0 })
    vim.api.nvim_win_call(win, function()
      vim.cmd 'normal! zt'
    end)
  end
end

function W.isvalid(winid)
  if type(winid) == 'number' then
    return vim.api.nvim_win_is_valid(winid)
  else
    return false
  end
end

function W.close(winid)
  -- safely close a window by its id.
  if W.isvalid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
end

function W.goto(winid)
  if winid == 0 or winid == vim.api.nvim_get_current_win() then
    -- already there
    return
  end
  if W.isvalid(winid) then
    vim.api.nvim_set_current_win(winid)
  end
end

--[[ Parsers ]]

local P = {}

function P.lua(otl, specs)
  -- returns idx, olines using lua spec patterns
  -- lua specs = {
  --   parser = 'lua',
  --   { pattern, [skip=true], [symbol=' ']}, = capture pattern
  --   ...
  -- }
  --
  -- captures of a specification pattern are simply glued together

  local idx, olines = {}, {}
  local ft = vim.bo[otl.sbuf].filetype
  local specs = M.config.outline[ft]
  if specs == nil then
    vim.notify('filetype ' .. ft .. ' has no specs', vim.log.levels.ERROR)
    return {}, {}
  end

  if specs == nil or #specs < 1 then
    vim.notify('oops1', vim.log.levels.ERROR)
    return idx, olines
  end

  local blines = vim.api.nvim_buf_get_lines(otl.sbuf, 0, -1, false)
  for linenr, line in ipairs(blines) do
    for _, spec in ipairs(specs) do
      local match = { string.match(line, spec[1]) }
      if #match > 0 then
        if not spec.skip then
          local entry = table.concat(match, ' ') -- combine the parts
          entry = string.gsub(entry, '%s+$', '') -- remove trailing spaces
          local symbol = spec.symbol or ''

          idx[#idx + 1] = linenr
          olines[#olines + 1] = string.format('%s%s', symbol, entry)
        end
        break
      end
    end
  end

  return idx, olines
end

function P.scm(otl, specs)
  -- returns idx, olines using a TS query
  -- 'config.outline.<ftype>' = {
  --   parser = 'scm',           -- these are the scm specs
  --   language = '..'           -- language name for <ftype>, e.g. 'lua'
  --   query = 'otl'             -- name of the outline scm query file to load
  --   depth = 0 .. n            -- max_depth to traverse (default: 0)
  -- }
  --
  local max_depth = specs.depth or 0
  local language, query = specs.language, specs.query
  local ts_query = vim.treesitter.query.get(language, query)
  if ts_query == nil then
    vim.notify(string.format('[error](%s) query %s not found or invalid', language, query), vim.log.levels.ERROR)
    return {}, {}
  end

  local parser, err = vim.treesitter.get_parser(otl.sbuf, language, {})
  if err ~= nil or parser == nil then
    vim.notify(vim.inspect(err), vim.log.levels.ERROR)
    return {}, {}
  end

  local tree = parser:parse()
  if tree == nil then
    vim.notify('[error] no tree returned by query parser', vim.log.levels.ERROR)
    return {}, {}
  end

  local root = tree[1]:root()
  if root == nil then
    vim.notify('[error] no CST root available: ' .. language, vim.log.levels.ERROR)
    return {}, {}
  end

  local olines = {}
  local idx = {}
  -- or query:iter_matches ?
  -- for _, node, meta in query:iter_captures(root, 0, 0, -1) do
  for _, node, meta, _ in ts_query:iter_captures(root, otl.sbuf) do
    -- ignoring the name and match return values of iter_captures
    local depth = ts_depth(node, root)
    local linenr = node:range()
    linenr = linenr + 1
    local prev_line = idx[#idx] or -1
    if depth <= max_depth and linenr ~= prev_line and meta.head then
      olines[#olines + 1] = ' ' .. meta.head
      idx[#idx + 1] = linenr
    end
  end
  return idx, olines
end

--[[ OTL funcs ]]

local O = {}

--- get outline, set otl.idx and fill otl.obuf with lines
--- @param otl table
function O.outline(otl)
  -- get the outline for otl.sbuf & create/fill owin/obuf if needed
  -- local lines = { " one", " ten", " twenty", " thirty", " sixty", " hundred" }
  -- otl.idx = { 1, 10, 20, 30, 60, 100 }

  local ft = vim.bo[otl.sbuf].filetype
  local specs = M.config.outline[ft]

  if specs == nil then
    vim.notify('filetype "' .. ft .. '" not supported')
    return
  end

  local parser = P[specs.parser]
  if parser == nil then
    vim.notify('parser "' .. specs.parser .. '" for filetype ' .. ft .. ' unknown', vim.log.levels.ERROR)
    return
  end

  local idx, olines = parser(otl, specs)

  if #idx == 0 or #olines == 0 then
    local msg = string.format('Parser %s failed for filetype %s', specs.parser, ft)
    vim.notify(msg, vim.log.levels.ERROR)
    return
  end

  otl.idx = idx
  otl.tick = vim.b[otl.sbuf].changedtick
  if otl.owin == nil then
    vim.api.nvim_command 'noautocmd topleft 40vnew'
    otl.obuf = vim.api.nvim_get_current_buf()
    otl.owin = vim.api.nvim_get_current_win()
  end

  vim.api.nvim_set_option_value('modifiable', true, { buf = otl.obuf })
  vim.api.nvim_buf_set_lines(otl.obuf, 0, -1, false, olines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = otl.obuf })
  return otl
end

---sync otl table between src/dst
---@param otl table
function O.sync(otl)
  -- store otl as src/dst buffer variable, assumes a valid otl
  -- alt: vim.b[otl.obuf].otl = otl
  vim.api.nvim_buf_set_var(otl.obuf, 'otl', otl)
  vim.api.nvim_buf_set_var(otl.sbuf, 'otl', otl)
  return otl
end

function O.settings(otl)
  -- otl window options
  vim.api.nvim_set_option_value('list', false, { win = otl.win })
  vim.api.nvim_set_option_value('winfixwidth', true, { win = otl.win })
  vim.api.nvim_set_option_value('number', false, { win = otl.win })
  vim.api.nvim_set_option_value('signcolumn', 'no', { win = otl.win })
  vim.api.nvim_set_option_value('foldcolumn', '0', { win = otl.win })
  vim.api.nvim_set_option_value('relativenumber', false, { win = otl.win })
  vim.api.nvim_set_option_value('wrap', false, { win = otl.win })
  vim.api.nvim_set_option_value('spell', false, { win = otl.win })
  vim.api.nvim_set_option_value('cursorline', true, { win = otl.win })
  vim.api.nvim_set_option_value('winhighlight', 'CursorLine:Visual', { win = otl.win })

  -- otl buffer options
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = otl.obuf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = otl.obuf })
  vim.api.nvim_set_option_value('buflisted', false, { buf = otl.obuf })
  vim.api.nvim_set_option_value('swapfile', false, { buf = otl.obuf })
  vim.api.nvim_set_option_value('modifiable', false, { buf = otl.obuf })
  vim.api.nvim_set_option_value('filetype', 'otl-outline', { buf = otl.obuf })

  -- otl keymaps
  local opts = { noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(otl.obuf, 'n', 'q', "<cmd>lua require'pdh.outline'.close()<cr>", opts)

  local up = "<cmd>lua require'pdh.outline'.up()<cr>"
  local down = "<cmd>lua require'pdh.outline'.down()<cr>"
  vim.api.nvim_buf_set_keymap(otl.obuf, 'n', '<Up>', up, opts)
  vim.api.nvim_buf_set_keymap(otl.obuf, 'n', 'K', up, opts)
  vim.api.nvim_buf_set_keymap(otl.obuf, 'n', '<Down>', down, opts)
  vim.api.nvim_buf_set_keymap(otl.obuf, 'n', 'J', down, opts)

  local shuttle = "<cmd>lua require'pdh.outline'.shuttle()<cr>"
  vim.api.nvim_buf_set_keymap(otl.obuf, 'n', '<cr>', shuttle, opts)
  vim.api.nvim_buf_set_keymap(otl.sbuf, 'n', '<cr>', shuttle, opts)

  -- otl autocmds
  vim.api.nvim_create_augroup('OtlAuGrp', { clear = true })
  vim.api.nvim_create_autocmd('BufWinLeave', {
    -- last window showing sbuf closed -> close otl.
    buffer = otl.sbuf,
    group = 'OtlAuGrp',
    desc = 'OTL wipe otl window and vars',
    callback = function()
      if vim.b[otl.sbuf].otl then
        -- triggered by something else than M.toggle
        M.close(otl.sbuf)
      end
    end,
  })
  vim.api.nvim_create_autocmd('BufWinLeave', {
    -- the otl buffer is going away (switch buf or close window)
    buffer = otl.obuf,
    group = 'OtlAuGrp',
    desc = 'OTL wipe otl window and vars',
    callback = function()
      if vim.b[otl.obuf].otl then
        -- triggered by something else than M.toggle
        M.close(otl.sbuf)
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinEnter', {
    -- Upon entering the otl window -> check changedtick & update if necessary
    buffer = otl.obuf,
    group = 'OtlAuGrp',
    desc = 'OTL maybe update outline',
    callback = function()
      if vim.b[otl.obuf].otl then
        local otick = otl.tick
        local stick = vim.b[otl.sbuf].changedtick
        if stick > otick then
          O.outline(otl)
        end
      end
    end,
  })
end

function O.nosettings(otl)
  -- remove otl keymaps in sbuf
  pcall(vim.api.nvim_buf_del_keymap, otl.sbuf, 'n', '<cr>')

  -- remove otl autogrp
  pcall(vim.api.nvim_del_augroup_by_name, 'OtlAuGrp')
end

function O.select(sline)
  -- given the linenr in sbuf (sline), find the closest match in otl.idx
  -- and move to the associated otl buffer line (oline)
  local line = 1
  local otl = vim.b[0].otl
  if otl then
    for otl_line, idx in ipairs(otl.idx) do
      if idx <= sline then
        line = otl_line
      end
    end
    vim.api.nvim_win_set_cursor(otl.owin, { line, 0 })
  end
end

--[[ OTL table ]]
-- otl = {
--   sbuf = source buffer number
--   swin = source window number
--   obuf = outline buffer number
--   owin = outline window number
--   tick = last changedtick number
--   idx = list of sbuf linenrs, indexed by obuf linenr
--
--   Outline provider for asciidoc, entry is an outline entry
--   https://github.com/msr1k/outline-asciidoc-provider.nvim/blob/main/lua/outline/providers/asciidoc.lua
--    local entry = {
--   kind = 15,
--   name = title,
--   selectionRange = {
--     start = { character = 1, line = line - 1 },
--     ['end'] = { character = 1, line = line - 1 },
--   },
--   range = {
--     start = { character = 1, line = line - 1 },
--     ['end'] = { character = 1, line = line - 1 },
--   },
--   children = {},
-- }
--
-- parent[#parent + 1] = entry
-- level_symbols[depth] = entry
-- }

--[[ MODULE ]]

M.config = {
  outline = {
    -- outliner specs by filetype -> spec (these are parser specific)
    -- [ ] add parser AST, home grown ast filter to outline
    rfc = {
      parser = 'lua',
      { '^RFC', skip = true }, -- skip page header
      { '%[Page%s-%d-%]$', skip = true }, -- skip page footer
      { '^%u.*$', symbol = ' ' }, -- line starts with Uppercase letter
      { '^%d.*$' }, -- line starts with a digit
    },
    help = {
      parser = 'lua',
      { '^(%u[%u%p%s]+)%s+', symbol = '' }, -- one or more UPPERCASE words
      { '%*([^*]+)%*$', symbol = ' ' }, -- the (last) *..* tag at end of the line
    },
    markdown = {
      parser = 'lua',
      { '^#%s(.*)$', symbol = '' },
      { '^##%s(.*)$', symbol = ' ' },
      { '^###%s(.*)$', symbol = '  ' },
      { '^###+%s+(.*)$', symbol = '   ' },
    },
    lua = {
      parser = 'scm',
      language = 'lua',
      query = 'otl', -- outline is already taken
      depth = 1,
    },
    elixir = {
      parser = 'scm',
      language = 'elixir',
      query = 'otl',
      depth = 5,
    },
  },
}

function M.open(buf)
  -- open otl window for given buf number
  buf = buf_sanitize(buf)

  if vim.b[buf].otl then
    vim.notify('[error](open) otl already exists?', vim.log.levels.ERROR)
    return
  end

  local otl = {}

  -- create new otl window with outline
  otl.sbuf = buf
  otl.swin = vim.api.nvim_get_current_win()
  if O.outline(otl) then
    O.settings(otl)
    O.sync(otl)
    local line = vim.api.nvim_win_get_cursor(otl.swin)[1]
    O.select(line)
  end
end

M.close = function(buf)
  -- close otl window, move to swin
  buf = buf_sanitize(buf)
  if buf == nil then
    vim.notify('[error](close) invalid buffer number', vim.log.levels.ERROR)
    return
  end

  local otl = vim.b[buf].otl
  if otl == nil then
    -- nothing todo
    return
  end

  -- wipe the otl association
  O.nosettings(otl)
  vim.b[otl.sbuf].otl = nil
  vim.b[otl.obuf].otl = nil

  W.close(otl.owin)
  W.goto(otl.swin)
end

M.shuttle = function()
  -- move back and forth between the associated otl windows
  local buf = vim.api.nvim_get_current_buf()
  local otl = vim.b[buf].otl

  if otl == nil then
    -- noop since there isn't an otl available
    return
  end

  local win = vim.api.nvim_get_current_win()
  local line = vim.api.nvim_win_get_cursor(win)[1]

  if buf == otl.sbuf then
    -- shuttle in *a* window showing sbuf, adopt it as swin and moveto otl
    otl.swin = win
    O.sync(otl)
    W.goto(otl.owin)
    O.select(line)
    return
  end

  if W.isvalid(otl.swin) and otl.sbuf == vim.api.nvim_win_get_buf(otl.swin) then
    -- shuttle called in the otl window and swin still shows sbuf
    line = otl.idx[line]
    W.goto(otl.swin)
    W.centerline(otl.swin, line)
    return
  end

  -- shuttle called in owin and need to adopt antoher swin
  otl.swin = vim.fn.bufwinid(otl.sbuf)
  if otl.swin == -1 then
    return M.close()
  else
    line = otl.idx[line]
    O.sync(otl)
    W.goto(otl.swin)
    W.centerline(otl.swin, line)
  end

  -- vim.notify("[error] shuttle: no window for src buf", vim.log.levels.ERROR)
end

M.toggle = function()
  -- open or close otl for current buffer
  local buf = vim.api.nvim_get_current_buf()
  local otl = vim.b[buf].otl

  if otl == nil then
    -- toggle for buf that has no otl, so create new otl
    return M.open(buf)
  end

  -- Note: toggle calls close, that wipes the otl's and closing the
  -- owin itriggers BufWinLeave for owin.
  M.close(otl.sbuf)
end

M.up = function()
  -- <Up> in otl window
  local buf = vim.api.nvim_get_current_buf()
  local otl = vim.b[buf].otl

  if otl == nil then
    return
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  -- TODO: make wrapping (cycle) configurable
  -- if line == 1 then
  --   line = vim.api.nvim_buf_line_count(0)
  -- else
  --   line = line - 1
  -- end
  if line > 1 then
    line = line - 1
  end

  -- W.centerline(otl.owin, line)
  pcall(vim.api.nvim_win_set_cursor, otl.owin, { line, 0 })
  line = otl.idx[line]
  W.centerline(otl.swin, line)
end

M.down = function()
  -- <Down> in otl window
  local buf = vim.api.nvim_get_current_buf()
  local otl = vim.b[buf].otl

  if otl == nil then
    return
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  -- TODO: make wrapping (cycle) configurable
  -- if line == vim.api.nvim_buf_line_count(0) then
  --   line = 1
  -- else
  --   line = line + 1
  -- end
  if line < vim.api.nvim_buf_line_count(0) then
    line = line + 1
  end

  -- W.centerline(otl.owin, line)
  pcall(vim.api.nvim_win_set_cursor, otl.owin, { line, 0 })
  line = otl.idx[line]
  W.centerline(otl.swin, line)
end

--[[ EXPERIMENT outliner CST ]]

local function get_fragments(node, fragments)
  local frags = {}
  for child, _ in node:iter_children() do
    for _, frag in ipairs(fragments) do
      if frag == child:type() then
        frags[#frags + 1] = vim.treesitter.get_node_text(child, 0)
        break
      end
    end
  end
  return frags
end

local stop_recurse = {
  block = true,
  table_constructor = true,
}
local gettxt = {
  function_declaration = false,
  function_definition = false,
  identifier = true,
  parameters = true,
  dot_index_expression = true,
  bracket_index_expression = true,
}

local function walk(node, acc)
  acc = acc or {}
  if stop_recurse[node:type()] then
    return acc
  end
  for child, name in node:iter_children() do
    local ctype = child:type()
    if gettxt[ctype] then
      acc[#acc + 1] = { ctype, name, vim.treesitter.get_node_text(child, 0, {}) }
    elseif gettxt[ctype] == false then
      acc[#acc + 1] = { ctype, name, nil }
    end
    acc = walk(child, acc)
  end
  return acc
end

local function print_tree(node, level)
  if stop_recurse[node:type()] then
    return
  end

  level = level or 0
  local pfx = string.rep(' ', level, '|')

  for child, name in node:iter_children() do
    local row, col, len = child:start()
    local ctype = child:type()
    local ctext = ''

    if col == 0 and level == 0 then
      vim.print(' ')
      vim.print(string.format('[%03d] %s', row + 1, vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]))
    end

    if gettxt[ctype] then
      ctext = ' ---> txt(' .. vim.treesitter.get_node_text(child, 0, {}) .. ')'
    end

    name = name or 'n/a'
    vim.print(string.format('%s- [%d](%d, %d) type(%s), name(%s)%s', pfx, level, row, col, child:type(), name, ctext))
    print_tree(child, level + 1)
  end
end

M.test = function()
  -- TODO: delete/comment out when done testing/developing
  -- :Show lua require'pdh.outline'.test() -> results in new Tab
  local parser = vim.treesitter.get_parser(0, 'lua', {})
  local tree = parser:parse(true)
  local root = tree[1]:root()
  local blines = vim.api.nvim_buf_get_lines(0, 1, -1, false)

  vim.print('tree ' .. vim.inspect(tree))
  vim.print('tree len ' .. #tree)
  vim.print('tree[1] ' .. vim.inspect(tree[1]))
  vim.print('parser:children() ' .. vim.inspect(parser:children()))

  print_tree(root)
  vim.print(string.rep('=', 30))

  vim.print('walker')
  -- iterate over root's direct children
  for child, name in root:iter_children() do
    local row, _, _ = child:start()
    local type = child:type()
    name = name or 'unnamed'
    vim.print('')
    vim.print(string.format('[%03d] %s', row + 1, blines[row]))
    vim.print(string.format('= type(%s), name(%s)', type, name))
    for _, elem in ipairs(walk(child)) do
      vim.print(elem)
    end
  end

  -- all sorts of info
  vim.print('\n-- vim.treesitter.language.inspect(lua)')
  vim.print(vim.treesitter.language.inspect('lua'))
  vim.print('\n-- vim.lsp.protocol.SymbolKind, maps idx->name and name->idx')
  vim.print(vim.lsp.protocol.SymbolKind)

  -- print predicate available
  vim.print('\n-- vim.treesitter.query.list_predicates()')
  vim.print(vim.treesitter.query.list_predicates())

  -- print directives available
  vim.print('\n-- vim.treesitter.query.list_directives()')
  vim.print(vim.treesitter.query.list_directives())

  -- handlers
  vim.print('\n-- vim.lsp.handlers (print vim.lsp to see a lot more)')
  vim.print(vim.lsp.handlers)

  -- locals (symbols?)
  vim.print('\n-- symbols via treesitter query "locals.scm"')
  local query = vim.treesitter.query.get('lua', 'locals')
  local linenr = -1
  for _, tree in ipairs(parser:trees()) do
    local subroot = tree:root()
    vim.print('\n subroot ' .. vim.inspect(tree))
    for id, node, meta in query:iter_captures(subroot, 0) do
      local name = query.captures[id]
      local range = { node:range() }
      local depth = ts_depth(node, subroot)
      local text = vim.treesitter.get_node_text(node, 0)
      if linenr ~= range[1] then
        linenr = range[1]
        vim.print(string.format('\n[%d] %s %s', linenr + 1, text, vim.inspect(range)))
      end
      vim.print({ depth, id, name, range, vim.treesitter.get_node_text(node, 0) })
    end
  end

  -- lsp client
  -- [ ] lsp client code examples
end

-- :luafile % -> will reload the module
require('plenary.reload').reload_module 'pdh.outline'

return M
