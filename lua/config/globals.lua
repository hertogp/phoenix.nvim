-- :h vim_diff
--   https://neovim.io/doc/user/vim_diff.html
--   https://neovim.io/doc/user/vim_diff.html#nvim-defaults

--[[ LOCAL ]]

local fs = vim.fs
local uv = require "luv"
local g = vim.g -- namespace for global variables
local go = vim.go -- namespace for global options
local api = vim.api

--[[

-]]

--[[ GLOBAL ]]

-- TODO: add T to dump a lua table, to be used as
-- :Show lua =T(table), e.g. like :Show lua =T(vim.b)
P = function(value)
  -- inspect a value and return it.
  print(vim.inspect(value))
  return value
end

RELOAD = function(...)
  -- ?? what does this do?
  return require("plenary.reload").reload_module(...)
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
  if #bufpath < 1 or bufpath == "." then
    bufpath = uv.cwd()
  end
  bufpath = fs.normalize(bufpath)
  local sentinels = {
    ".git",
    ".gitignore",
    ".mise.toml",
    "stylua.toml",
    ".codespellrc",
    "Makefile",
    ".svn",
    ".bzr",
    ".hg",
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
g.netrw_browsex_viewer = "xdg-open"
g.neomake_open_list = 2
g.neomake_list_height = 20
g.neomake_javascript_enabled_makers = { "eslint" }
g.neomake_scss_enabeld_makers = { "stylelint" }
g.neomake_python_pylint_exe = "pylint3"
g.neomake_python_enabled_makers = { "pylint", "flake8" }
g.neomake_elixir_enabled_makers = { "credo" }

g.jsx_ext_required = 0
g.jsx_ext_required = 1
g.jsdoc_allow_input_prompt = 1
g.jsdoc_input_description = 1
g.jsdoc_return = 0
g.jsdoc_return_type = 0
g.vim_json_syntax_conceal = 0
g.gruvbox_transp_bg = 1

-- for pw <file>
g.tgpgOptions = "-q --batch --force-mdc --no-secmem-warning"

g.neoterm_default_mod = "vert"
-- automatically start a REPL works via the TREPLxx-commands
-- or use Topen iex -S mix
g.neoterm_auto_repl_cmd = 0
g.neoterm_direct_open_repl = 1
g.neoterm_autoscroll = 1

--[[ global options ]]

go.startofline = false
-- are these in vim.go namespace of vim.o namespace?
-- TODO: packpath defaults to runtimepath, so is this necessary?
--del go.packpath = go.runtimepath

--[[ global user commands ]]

-- Show
--------
-- run a vim command and show it's output, e.g.
--   Show let g:      -- show all global variables in a new tab
--   Show let b:      -- show all buffer variables in a new tab
--   Show let w:      -- show all window variables in a new tab
--   Show lua =vim    -- show the lua vim table
--   Show map         -- show all mappings
local function show_in_tab(t)
  -- x = vim.api.nvim_exec(t.args, x)
  local ok, x = pcall(function()
    local cmd = api.nvim_parse_cmd(t.args, {})
    local output = api.nvim_cmd(cmd, { output = true })
    -- return lines table, no newlines allowed by nvim_buf_set_lines()
    local lines = {}
    -- return vim.split(lines, "\r?\n", {trimempty = true}
    for line in output:gmatch "[^\r\n]+" do
      table.insert(lines, line)
    end
    return lines
  end)

  -- open a new tab
  api.nvim_command "tabnew"
  -- api.nvim_buf_set_option(0, 'filetype', 'nofile')
  -- api.nvim_buf_set_option(0, 'buftype', 'nofile')
  api.nvim_buf_set_option(0, "bufhidden", "wipe")
  api.nvim_buf_set_option(0, "swapfile", false)
  api.nvim_buf_set_option(0, "buflisted", false)
  api.nvim_buf_set_lines(0, 0, 0, false, { "Show " .. t.args, "-----" })

  -- insert results (good or bad) in the buffer
  if ok then
    api.nvim_buf_set_lines(0, -1, -1, false, x)
  else
    api.nvim_buf_set_lines(0, -1, -1, false, { "error", vim.inspect(x) })
  end

  api.nvim_buf_set_option(0, "modified", false)
  api.nvim_buf_set_keymap(0, "n", "q", "<cmd>close<cr>", { noremap = true, silent = true })
end

api.nvim_create_user_command(
  "Show",
  show_in_tab,
  { complete = "shellcmd", nargs = "+", desc = "Show cmd output in a new tab" }
)

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

api.nvim_create_user_command("SaveKeepPos", save_keep_pos, {})
