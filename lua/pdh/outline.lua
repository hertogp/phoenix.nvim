-- File: ~/.config/nvim/lua/pdh/outline.lua
-- [[ Find outline for various filetypes ]]

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
--]]

--[[ GLOBALS ]]

local M = {}

M.queries = {
  -- Filetype specific tree-sitter queries that yield an outline
  -- see https://github.com/elixir-lang/tree-sitter-elixir/tree/main/queries
  elixir = [[
    (((comment) @c (#lua-match? @c "^[%s#]+%[%[[^\n]+%]%]")) (#join! "head" "" "[c] " @c))
    ((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "def")) (#join! "head" "" "[f] " @a))
    ((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "defp")) (#join! "head" "" "[p] " @a))
    ((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "test")) (#join! "head" "" "[t] " @a))
    ((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "describe")) (#join! "head" "" "[d] " @a))
    ((call target: (((identifier) ((arguments) @a)) @x)(#any-of? @x "defguard" "defguardp")) (#join! "head" "" "[g] " @a))
    ((call target: (((identifier) ((arguments) @a)) @x)(#any-of? @x "defmodule" "alias")) (#join! "head" "" "[M] " @x " " @a))
    ((((unary_operator (call (((identifier) @i)(#not-any-of? @i "doc" "spec" "typedoc" "moduledoc")))) @m))(#join! "head" "" "[@] " @m))
    ((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "defimpl")) (#join! "head" "" "[I] " @a))
    ((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "defmacro")) (#join! "head" "" "[m] " @a))
    ((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "defstruct")) (#join! "head" "" "[S] " @a))
    ((call target: (((identifier) ((arguments) @a)) @x)(#eq? @x "use")) (#join! "head" "" "[U] " @a))
  ]],

  -- (((unary_operator (call (identifier) @h)) @head) (#not-any-of? @h "spec" "doc" "moduledoc"))

  lua = [[
    (((comment) @c (#lua-match? @c "^--%[%[[^\n]+%]%]$")) (#join! "head"  "" "[-] " @c))
    ((function_declaration (identifier) @a (parameters) @b (#join! "head" "" "[f] " @a @b)))
    ((function_declaration (dot_index_expression) @a (parameters) @b (#join! "head" "" "[f] " @a @b)))
    ((assignment_statement
      ((variable_list) @a) (("=") @b)
      (expression_list (function_definition (("function") @c) ((parameters)@d))))
      (#join! "head" "" "[f] " @a " " @b " " @c @d))
    (((assignment_statement) @head) (#join! "head" "" "[s] " @head))
    (((variable_declaration) @head) (#join! "head" "" "[v] " @head))
    ]],

  markdown = [[
    ((section (atx_heading) @head) (#join! "head" "" @head))
    ((setext_heading (paragraph) @head) (#join! "head" "" @head))
  ]],
}

M.depth = {
  -- max depth at which a tree-sitter query can generate a heading
  elixir = 5,
  lua = 1,
  markdown = 6,
}

--[[ OUTLINERS ]]

local O = {}

O['lua'] = function(otl, specs)
  -- returns idx, olines
  local idx, olines = {}, {}

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
          local entry = table.concat(match, ' ')
          local symbol = spec.symbol or ''

          idx[#idx + 1] = linenr
          olines[#olines + 1] = string.format('%s%s', symbol, entry)
        else
          break
        end
      end
    end
  end

  return idx, olines
end

--[[ BUFFER funcs ]]

local function buf_sanitize(buf)
  -- return a real, valid buffer number or nil
  if buf == nil or buf == 0 then
    return vim.api.nvim_get_current_buf()
  elseif vim.api.nvim_buf_is_valid(buf) then
    return buf
  end
  return nil
end

--[[ delme


--]]

--[[ WINDOW funcs ]]

local function win_centerline(win, linenr)
  -- try to center linenr in window win
  if vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_set_cursor, win, { linenr, 0 })
    vim.api.nvim_win_call(win, function()
      vim.cmd 'normal! zz'
    end)
  end
end

local function win_isvalid(winid)
  if type(winid) == 'number' then
    return vim.api.nvim_win_is_valid(winid)
  else
    return false
  end
end

local function win_close(winid)
  -- safely close a window by its id.
  if win_isvalid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
end

local function win_goto(winid)
  if winid == 0 or winid == vim.api.nvim_get_current_win() then
    return
  end
  if vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_set_current_win(winid)
  end
end

--[[ TS funcs ]]

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

local function ts_outline(bufnr)
  -- return two lists: {linenrs}, {lines} based on a filetype specific TS query
  local ft = vim.bo[bufnr].filetype
  local max_depth = M.depth[ft] or 0
  local qry = M.queries[ft]
  if qry == nil then
    return {}, {}
  end

  local query = vim.treesitter.query.parse(ft, qry)

  local parser = vim.treesitter.get_parser(bufnr, ft, {})
  if parser == nil then
    return {}, {}
  end

  local tree = parser:parse()
  if tree == nil then
    return {}, {}
  end

  local root = tree[1]:root()
  if root == nil then
    vim.notify('[ERROR] no AST root available: ' .. ft, vim.log.levels.ERROR)
    return {}, {}
  end

  local blines = {}
  local idx = {}
  -- local lines
  -- for _, node, meta in query:iter_captures(root, 0, 0, -1) do
  for _, node, meta in query:iter_captures(root, bufnr) do
    local depth = ts_depth(node, root)
    local linenr = node:range()
    linenr = linenr + 1
    local prev_line = idx[#idx] or -1
    if depth <= max_depth and linenr ~= prev_line and meta.head then
      blines[#blines + 1] = ' ' .. meta.head
      idx[#idx + 1] = linenr
    end
  end
  return idx, blines
end

--[[ RGX funcs ]]

local RGX = {
  rfc = {
    '^%d.*',
    -- do not use ^%u.* since that'll match page header/footer as well
    '^Network.*',
    '^Request.*',
    '^Category.*',
    '^Copyright.*',
    '^Status.*',
    '^Table.*',
    '^Abstract.*',
    '^Appendix.*',
    '^Acknowledgements.*',
    '^Contributors.*',
    '^Author.*',
  },
}

local function rgx_outline(bufnr)
  -- return two lists: {linenrs}, {lines} based on a filetype specific TS query
  local idx, olines = {}, {}
  local ft = vim.bo[bufnr].filetype
  local rgxs = RGX[ft]

  if rgxs == nil then
    return idx, olines
  end

  local blines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for n, line in ipairs(blines) do
    for _, rgx in ipairs(rgxs) do
      if string.match(line, rgx) then
        idx[#idx + 1] = n
        olines[#olines + 1] = line
        break -- on first match
      end
    end
  end
  return idx, olines
end

--[[ OTL funcs ]]

---get outline, set otl.idx and fill otl.obuf with lines
---@param otl table
local function otl_outline(otl)
  -- get the outline for otl.sbuf & create/fill owin/obuf if needed
  -- local lines = { " one", " ten", " twenty", " thirty", " sixty", " hundred" }
  -- otl.idx = { 1, 10, 20, 30, 60, 100 }

  local ft = vim.bo[otl.sbuf].filetype
  local spec = M.config.outline[ft]

  if spec == nil then
    vim.notify('filetype ' .. ft .. 'not supported')
    return
  end

  local parser = O[spec.parser]
  if parser == nil then
    vim.notify('parser "' .. spec.parser .. '" for filetype ' .. ft .. ' unknown', vim.log.levels.ERROR)
    return
  end

  local idx, olines = parser(otl, spec)

  -- local idx, olines
  -- if M.queries[ft] then
  --   idx, olines = ts_outline(otl.sbuf)
  -- else
  --   idx, olines = rgx_outline(otl.sbuf)
  -- end

  if #idx == 0 or #olines == 0 then
    local msg = string.format('Parser %s failed for filetype %s', spec.parser, ft)
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
local function otl_sync(otl)
  -- store otl as src/dst buffer variable, assumes a valid otl
  -- alt: vim.b[otl.obuf].otl = otl
  vim.api.nvim_buf_set_var(otl.obuf, 'otl', otl)
  vim.api.nvim_buf_set_var(otl.sbuf, 'otl', otl)
  return otl
end

local function otl_settings(otl)
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
          otl_outline(otl)
        end
      end
    end,
  })
end

local function otl_nosettings(otl)
  -- remove otl keymaps in sbuf
  pcall(vim.api.nvim_buf_del_keymap, otl.sbuf, 'n', '<cr>')

  -- remove otl autogrp
  pcall(vim.api.nvim_del_augroup_by_name, 'OtlAuGrp')
end

local function otl_select(sline)
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

--['[ MODULE ]]
M.config = {
  outline = {
    rfc = {
      parser = 'lua',
      { '^RFC', skip = true }, -- skip page header
      { '%[Page%s-%d-%]$', skip = true }, -- skip page footer
      { '^%u.*$', symbol = ' ' }, -- line starts with Uppercase letter
      { '^%d.*$' }, -- line starts with a digit
      -- {'(Network)%s+(%S+)'},
      -- { '^Request.*'},
      -- { '^Category.*'},
      -- { '^Copyright.*'},
      -- { '^Status.*'},
      -- { '^Table.*'},
      -- { '^Abstract.*'},
      -- { '^Appendix.*'},
      -- { '^Acknowledgements.*'},
      -- { '^Contributors.*'},
      -- { '^Author.*'},
    },
    help = {
      -- string.match('qwerty *asdt*', '^(.*)%*([^%*]-)%*$) -> qwerty
      -- { string.match('qwerty *asdt*', '^(.*)%*([^%*]-)%*$) } -> { "qwerty", "asdf" }
      -- include string.match inside a table constructor(!) to see captures
      parser = 'lua',
      { '%*[^*]%*$', symbol = '[f]' },
    },
    lua = {
      parser = 'treesitter',
      [[
        (((comment) @c (#lua-match? @c "^--%[%[[^\n]+%]%]$")) (#join! "head"  "" "[-] " @c))
        ((function_declaration (identifier) @a (parameters) @b (#join! "head" "" "[f] " @a @b)))
        ((function_declaration (dot_index_expression) @a (parameters) @b (#join! "head" "" "[f] " @a @b)))
        ((assignment_statement
          ((variable_list) @a) (("=") @b)
          (expression_list (function_definition (("function") @c) ((parameters)@d))))
          (#join! "head" "" "[f] " @a " " @b " " @c @d))
        (((assignment_statement) @head) (#join! "head" "" "[s] " @head))
        (((variable_declaration) @head) (#join! "head" "" "[v] " @head))
      ]],
    },
  },
}
M.open = function(buf)
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
  if otl_outline(otl) then
    otl_settings(otl)
    otl_sync(otl)
    local line = vim.api.nvim_win_get_cursor(otl.swin)[1]
    otl_select(line)
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
  otl_nosettings(otl)
  vim.b[otl.sbuf].otl = nil
  vim.b[otl.obuf].otl = nil

  win_close(otl.owin)
  win_goto(otl.swin)
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
    otl_sync(otl)
    win_goto(otl.owin)
    otl_select(line)
    return
  end

  if win_isvalid(otl.swin) and otl.sbuf == vim.api.nvim_win_get_buf(otl.swin) then
    -- shuttle called in the otl window and swin still shows sbuf
    line = otl.idx[line]
    win_goto(otl.swin)
    win_centerline(otl.swin, line)
    return
  end

  -- shuttle called in owin and need to adopt antoher swin
  otl.swin = vim.fn.bufwinid(otl.sbuf)
  if otl.swin == -1 then
    return M.close()
  else
    line = otl.idx[line]
    otl_sync(otl)
    win_goto(otl.swin)
    win_centerline(otl.swin, line)
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
  if line == 1 then
    line = vim.api.nvim_buf_line_count(0)
  else
    line = line - 1
  end

  win_centerline(otl.owin, line)
  line = otl.idx[line]
  win_centerline(otl.swin, line)
end

M.down = function()
  -- <Down> in otl window
  local buf = vim.api.nvim_get_current_buf()
  local otl = vim.b[buf].otl

  if otl == nil then
    return
  end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  if line == vim.api.nvim_buf_line_count(0) then
    line = 1
  else
    line = line + 1
  end

  win_centerline(otl.owin, line)
  line = otl.idx[line]
  win_centerline(otl.swin, line)
end

-- : luafile % (or \\x) -> will reload the module
require('plenary.reload').reload_module 'pdh.outline'

return M
