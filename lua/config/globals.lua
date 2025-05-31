-- :h vim_diff
--   https://neovim.io/doc/user/vim_diff.html
--   https://neovim.io/doc/user/vim_diff.html#nvim-defaults

--[[ LOCAL ]]

local fs = vim.fs
local uv = require 'luv'
local g = vim.g -- namespace for global variables
local go = vim.go -- namespace for global options
local api = vim.api

--[[

-]]

--[[ GLOBAL ]]

function Vim_run_cmd()
  -- execute a vim command enclosed in backticks (`:cmd ..`)
  -- Examples: `:Show lua =vim.treesitter` or `:tab h treesitter`
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local line = vim.api.nvim_get_current_line()
  vim.print(line)
  local vimcmd = nil
  local cmds = {}
  -- collect all commands on current line
  for _, cmd, args, endpos in string.gmatch(line, '()`:%s*(%g+)%s+([^`]+)`()') do
    cmds[#cmds + 1] = { endpos, cmd, args }
  end
  -- find first cmd that ends after cursor
  for idx, cmd in ipairs(cmds) do
    if col < cmd[1] or idx == #cmds then
      vimcmd = cmd[2] .. ' ' .. cmd[3]
      if string.match(vimcmd, '^h') then
        -- show help in new tab
        vimcmd = 'tab ' .. vimcmd
      end
      break
    end
  end
  if vimcmd then
    vim.cmd(vimcmd)
  else
    vim.notify('no vim command (`:cmd .. `) found on current line', vim.log.levels.WARN)
  end
end
-- if cmd and #cmd > 0 then
--   vim.print(vim.inspect(cmd))
--   if string.match(cmd[1], '^h') then
--     table.insert(cmd, 1, 'tab')
--   end
--   local str = table.concat(cmd, ' ')
-- vim.print(vim.inspect(cmd))
-- vim.cmd(str)
-- `:h treesitter`
-- end

-- TODO: add T to dump a lua table, to be used as
-- :Show lua =T(table), e.g. like :Show lua =T(vim.b)
P = function(value)
  -- inspect a value and return it.
  print(vim.inspect(value))
  return value
end

RELOAD = function(...)
  -- reload a plugin/package
  return require('plenary.reload').reload_module(...)
end

R = function(name)
  -- force a reload for given module name
  RELOAD(name)
  return require(name)
end

function Project_root(bufnr)
  -- used by a.o. ~/.config/nvim/lua/pdh/telescope.lua (maybe keep it local there?)
  -- get the project's root directory for a given buffer or from cwd
  -- if not found return nil
  bufnr = bufnr or 0
  -- scratch buffers -> fallback to cwd
  local bufpath = vim.fs.dirname(api.nvim_buf_get_name(bufnr))
  if #bufpath < 1 or bufpath == '.' then
    bufpath = uv.cwd()
  end
  bufpath = fs.normalize(bufpath)
  local sentinels = {
    '.git',
    '.gitignore',
    '.mise.toml',
    '.notes',
    'stylua.toml',
    '.codespellrc',
    'Makefile',
    '.svn',
    '.bzr',
    '.hg',
  }
  local repo_dir = fs.find(sentinels, { path = bufpath, upward = true })[1]
  if repo_dir then
    return vim.fs.dirname(repo_dir)
  else
    return nil
  end
end

--[[ NOTES ]]
-- vim.o     get/set buffer/window OPTIONS    :set
-- vim.bo    get/set buffer-scoped OPTIONS    :set and :setlocal
-- vim.wo    get/set window-scoped OPTIONS    :set (see :he vim.wo)
-- vim.go    get/set vim global OPTIONS       :setglobal
-- Show      use :Show set / setlocal / getglobal to show the scoped options
-- vim.g     get/set vim global var's
-- vim.opt   special OO-interface
-- These are equivalents
-- 1. :set wildignore=*.o,*.a,__pycache__
-- 2. vim.o.wildignore = '*.o,*.a,__pycache__'
-- 3. vim.opt.wildignore = {'*.o', '*.a', '__pycache__'}
-- you can also do set+=, like this:
-- vim.opt.wildignore:append {'*.o', '*.a', '__pycache__'}
-- set-= -> ..:remove {}
-- set^= -> ..:prepend {}
-- accessing vim.opt.xxx returns an object -> vim.opt.xxx:get() yields the value

-- map(local)leader are defined in ~/.config/nvim/config/lazy.lua

--[[ global variables ]]
g.have_nerd_font = true
g.netrw_browsex_viewer = 'xdg-open'
g.neomake_open_list = 2
g.neomake_list_height = 20
g.neomake_javascript_enabled_makers = { 'eslint' }
g.neomake_scss_enabeld_makers = { 'stylelint' }
g.neomake_python_pylint_exe = 'pylint3'
g.neomake_python_enabled_makers = { 'pylint', 'flake8' }
g.neomake_elixir_enabled_makers = { 'credo' }

g.jsx_ext_required = 0
g.jsx_ext_required = 1
g.jsdoc_allow_input_prompt = 1
g.jsdoc_input_description = 1
g.jsdoc_return = 0
g.jsdoc_return_type = 0
g.vim_json_syntax_conceal = 0
g.gruvbox_transp_bg = 1

-- for pw <file>
g.tgpgOptions = '-q --batch --force-mdc --no-secmem-warning'

g.neoterm_default_mod = 'vert'
-- automatically start a REPL works via the TREPLxx-commands
-- or use Topen iex -S mix
g.neoterm_auto_repl_cmd = 0
g.neoterm_direct_open_repl = 1
g.neoterm_autoscroll = 1

--[[ global options ]]

go.startofline = false

--[[ global user commands ]]
--

-- Show
--------
--- vim.{b, t, w, g} buffer, tab, window, global variables
--- vim.{b,t,w}[id].name specific buffer, window or tab variables
--- vim.{bo, to, wo, o} (current) buffer, tab, window or global options
--- vim.{opt, opt_local} global/local (buffer/tab/window) options
---
-- run a vim command and show it's output, e.g.
--   Show map         -- show all mappings
--   Show map <buffer> -- show buffer local keymap
--   Show echo &runtimepath (or &rtp) and do s/,/\r/g
--   Show read ! echo $PATH
--   Show lua =vim.opt.runtimepath
--   Show lua =vim.opt.packpath
--   Show echo nvim_get_runtime_file("lua/", v:true)
--   Show echo api_info().functions->map("v:val.name")->filter("v:val=~'^nvim_buf'")
local function show_in_tab(t)
  -- x = vim.api.nvim_exec(t.args, x)
  local ok, x = pcall(function()
    local cmd = api.nvim_parse_cmd(t.args, {})
    local output = api.nvim_cmd(cmd, { output = true })
    -- return lines table, no newlines allowed by nvim_buf_set_lines()
    return vim.split(output, '\n', { 1 })
  end)

  -- open a new tab
  api.nvim_command 'tabnew'
  vim.api.nvim_set_option_value('filetype', 'nofile', { buf = 0 })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = 0 })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = 0 })
  vim.api.nvim_set_option_value('buflisted', false, { buf = 0 })
  vim.api.nvim_set_option_value('swapfile', false, { buf = 0 })
  vim.api.nvim_buf_set_lines(0, 0, 0, false, { 'Show ' .. t.args, '-----' })

  -- insert results (good or bad) in the buffer
  if ok then
    api.nvim_buf_set_lines(0, -1, -1, false, x)
  else
    api.nvim_buf_set_lines(0, -1, -1, false, { 'error', vim.inspect(x) })
  end

  -- api.nvim_buf_set_option(0, 'modified', false)
  vim.api.nvim_set_option_value('modified', false, { buf = 0 })
  api.nvim_buf_set_keymap(0, 'n', 'q', '<cmd>close<cr>', { noremap = true, silent = true })
end

api.nvim_create_user_command(
  'Show',
  show_in_tab,
  { complete = 'shellcmd', nargs = '+', desc = 'Show cmd output in a new tab' }
)
api.nvim_create_user_command('ShowVarsGlobal', 'Show let g:', { desc = 'Show global vars' })
api.nvim_create_user_command('ShowVarsBuffer', 'Show let b:', { desc = 'Show buffer vars' })
api.nvim_create_user_command('ShowVarsWindow', 'Show let w:', { desc = 'Show window vars' })
api.nvim_create_user_command('ShowVarsVim', 'Show let v:', { desc = 'Show Vim (predefined) vars' })
api.nvim_create_user_command('ShowOptionsAll', 'Show set all', { desc = 'Show all options' })
api.nvim_create_user_command('ShowOptionsLocal', 'Show setlocal all', { desc = 'Show buf/win local options' })
api.nvim_create_user_command('ShowOptionsGlobal', 'Show setglobal all', { desc = 'Show buf/win global options' })
api.nvim_create_user_command(
  'ShowOptionsInfo',
  'Show lua =vim.api.nvim_get_all_options_info()',
  { desc = 'Show opt.info' }
)
api.nvim_create_user_command('ShowKeys', 'Show map', { desc = 'Show buffer local keys' })
api.nvim_create_user_command('ShowBufferKeys', 'Show map <buffer>', { desc = 'Show buffer local keys' })
api.nvim_create_user_command('ShowVimTable', 'Show lua =vim', { desc = 'Show Lua vim table' })
api.nvim_create_user_command('ShowVimApi', 'Show lua =vim.api', { desc = 'Show Lua vim.api table' })
api.nvim_create_user_command('ShowVimApiInfo', 'Show lua =vim.print(vim.fn.api_info())', { desc = 'Show vim.api info' })
api.nvim_create_user_command('ShowVimFn', 'Show lua =vim.api', { desc = 'Show Lua vim.fn table' })
api.nvim_create_user_command('ShowSysEnv', 'Show lua =vim.fn.environ()', { desc = 'Show shell env' })
api.nvim_create_user_command('ShowHighlights', 'Show hi', { desc = 'Show highlights (without highlighting)' })
-- vim.spairs is (key) sorted pairs, see below for nice table func additions
-- https://github.com/premake/premake-core/blob/master/src/base/table.lua

local function save_keep_pos()
  -- update a buffer (i.e. write if modified) without changing its split views
  -- Notes:
  -- - winsaveview -> gives cursor position as well as the linenr op topline in the window
  -- - winrestview -> you can hand it a table that does not have all the values returned
  --                  by winsaveview (e.g. winrestview({topline = 10}) will scroll the window
  --                  such that the 10th line is shown as first line of the window.
  local bufnr = vim.api.nvim_get_current_buf()
  local winids = vim.fn.win_findbuf(bufnr)
  local views = {}

  for _, winid in ipairs(winids) do
    views[winid] = vim.api.nvim_win_call(winid, vim.fn.winsaveview)
  end

  vim.cmd.update()

  for winid, view in pairs(views) do
    vim.api.nvim_win_call(winid, function()
      vim.fn.winrestview(view)
    end)
  end
end

api.nvim_create_user_command('SaveKeepPos', save_keep_pos, {})

function Synstack()
  -- return a list of syntax items under cursor
  -- synstack works only for vim regex based syntax, not tree-sitter
  -- local buf = vim.fn.bufname(0)
  -- see: vim.inspect_pos() as well (!)
  local row = vim.fn.line('.')
  local col = vim.fn.col('.')
  -- synIDattr(n, "name") -> yields the name
  local stack = vim.fn.synstack(row, col)
  if #stack > 0 then
    for _, id in ipairs(stack) do
      local id2 = vim.fn.synIDtrans(id)
      local n1 = vim.fn.synIDattr(id, 'name')
      local n2 = vim.fn.synIDattr(id2, 'name')
      P({ id, n1, id2, n2 })
    end
  else
    local captures = vim.treesitter.get_captures_at_cursor(0)
    P({ 'ts captures', captures })
    -- vim.tree-sitter.get_captures_at_pos(bufnr, vim.fn.line('.')-1, vim.fn.col('.')-1)
    -- ts captures at
  end
end
