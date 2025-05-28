-- NOTE: colorschemes.lua runs autocmds before loading a colorscheme

local api = vim.api
-- local fs = vim.fs
-- local nmap = function(keys, cmd, opts)
--   vim.keymap.set("n", keys, cmd, opts)
-- end

-- helpers
local function bufkey(mode, keys, cmd, opts)
  -- map key for current buffer only
  vim.api.nvim_buf_set_keymap(0, mode, keys, cmd, opts)
end

-- Notes:
-- - :au <Event> shows all autocommands for <Event>
-- - :h event shows a lot of events
-- - :h lua_stdlib
-- - :h lua-vim
-- - :h api-global -- here's where the vim.api funcs are documented
-- - Show lua =vim  -> shows the lua table for vim
-- - Show lua =vim.api
-- - Show lua =vim.loop
-- - Show lua =vim.api.nvim_get_all_options_info()
-- - Show let b:  -- shows all buffer variables

-- Remove all trailing whitespace on save
-- from https://github.com/Allaman/nvim/blob/main/lua/autocmd.lua
local TrimWhiteSpaceGrp = api.nvim_create_augroup('TrimWhiteSpaceGrp', { clear = true })
api.nvim_create_autocmd('BufWritePre', { command = [[:%s/\s\+$//e]], group = TrimWhiteSpaceGrp })

--[[ EasyQuit ]]
--- use q to quit all sorts of nofile-like buffers
local EasyQuitTable = {
  ['help'] = true,
  ['nofile'] = true,
  ['nowrite'] = true,
  ['quickfix'] = true,
  ['loclist'] = true,
  ['prompt'] = true,
  [''] = false,
}

local EasyQuit = api.nvim_create_augroup('EasyQuit', { clear = true })
api.nvim_create_autocmd({ 'FileType' }, {
  group = EasyQuit,
  callback = function()
    -- TODO: maybe switch to just check that buftype ~= "" ?
    -- since only `normal` buffers do not have a buftype
    -- P('FileType EasyQuit called for btype is ' .. vim.bo.buftype .. ', and ftype is ' .. vim.bo.filetype)
    if EasyQuitTable[vim.bo.buftype] or EasyQuitTable[vim.bo.filetype] then
      -- '!' forces the close command even if modified (e.g. a prompt buffer)
      -- vim.api.nvim_buf_set_keymap(0, 'n', 'q', '<cmd>close!<cr>', { noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(0, 'n', 'q', ':bdelete<cr>', { noremap = true, silent = true })
    end
  end,
})

--[[ RESUME editing ]]
-- go to last loc when opening a buffer
api.nvim_create_autocmd('BufReadPost', {
  -- command = [[if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif]]
  callback = function()
    local mark = api.nvim_buf_get_mark(0, '"')
    local lines = api.nvim_buf_line_count(0)
    local linenr = mark[1]

    -- print("BufReadPost triggered, mark is " .. vim.inspect(mark))
    if linenr > 1 and linenr < lines then
      api.nvim_win_set_cursor(0, mark)
    end
  end,
})

--[[ auPandoc ]]
local auPandoc = api.nvim_create_augroup('auPandoc', { clear = true })
api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown', 'pandoc' },
  group = auPandoc,
  callback = function()
    local opts = { noremap = true, silent = true }
    -- <s-f4> actually comes out as <f16> ?
    bufkey('n', '<F16>', '<cmd>silent make|redraw!|copen<cr>', opts)
    bufkey('n', '<F4>', '<cmd>silent make|redraw!|call jobstart(["xdg-open", expand("%:r").".pdf"])<cr>', opts)
    vim.cmd [[compiler pandoc]]
  end,
})

--[[ auElixir ]]
local auElixir = api.nvim_create_augroup('auElixir', { clear = true })
api.nvim_create_autocmd('FileType', {
  pattern = 'elixir',
  group = auElixir,
  callback = function(event)
    -- overrides neoterm's check for config/config.exs which lib's don't have
    if vim.fn.filereadable 'mix.exs' then
      vim.cmd [[call neoterm#repl#set('iex -S mix')]]
    else
      vim.cmd [[call neoterm#repl#set('iex')]]
    end
  end,
})
api.nvim_create_autocmd('BufWritePost', {
  pattern = { '*.ex', '*.exs' },
  group = auElixir,
  command = [[silent :MixFormat]],
})

--[[ auLua ]]
-- local auLua = api.nvim_create_augroup("auLua", { clear = true })
-- api.nvim_create_autocmd("BufWritePre", {
--   group = auLua,
--   pattern = { "*.lua" },
--   callback = function()
--     -- you need a stylua.toml somewhere
--     require("stylua").format()
--   end,
-- })
