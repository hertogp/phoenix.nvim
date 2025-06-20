-- KEYMAP
-- NOTES:
--   most are defined in the lua/plugins/<plugin>.lua files
--   here we define those that are more generic or won't fit in the files above

--[[ HELPERS ]]
local nmap = function(keys, cmd, description)
  local d = 'USR: ' .. (description or '?')
  vim.keymap.set('n', keys, cmd, { noremap = true, silent = true, desc = d })
end
local imap = function(keys, cmd, description)
  local d = 'USR: ' .. (description or '?')
  vim.keymap.set('i', keys, cmd, { noremap = true, silent = true, desc = d })
end

--[[ EDITING ]]

nmap('Q', 'gq}', 'format paragraph')
nmap('q', '<Nop>', 'set to noop')
nmap('Y', 'y$', '[Y] till end of line') -- yank till eol, like D deletes till eol
nmap('<c-left>', ':vertical resize +2<cr>')
nmap('<c-right>', ':vertical resize -2<cr>')
nmap('<c-up>', ':resize -2<cr>')
nmap('<c-down>', ':resize +2<cr>')

-- use <M-j> (alt-j) to split a line, like <S-j> (shift-j) combines lines
nmap('<m-j>', 'i<cr><esc>', 'split line at cursor')
imap('<c-p>', '<c-p><c-n>', 'invoke keyword completion')
imap('<c-n>', '<c-n><c-p>', 'invoke keyword completion')

-- save & redo/undo
imap('jj', '<esc>', 'escape to normal mode')
nmap('R', '<c-r>', '[R]edo')
imap('<c-s>', '<esc><cmd>SaveKeepPos<cr>', 'save file, keep position')
nmap('<c-s>', '<cmd>SaveKeepPos<cr>', 'save file, keep position')
nmap('<space>c', ":lua require'pdh.snacks'.codespell(0)<cr>", 'check spelling in buf')
nmap('<space>C', ":lua require'pdh.snacks'.codespell()<cr>", 'check spelling in dir')

-- function kyes
nmap('<f5>', ':redraw!', 'redraw screen')

--[[ CODING ]]

--[[ NAVIGATE ]]
nmap('<c-n>', '<cmd>nohl<cr>', 'clear search highlights')
-- keep centered when jumping
nmap('n', 'nzz', 'next match, centered')
nmap('N', 'Nzz', 'previous match, centered')
nmap('*', '*zz', 'next match on WORD, centered')
nmap('#', '#zz', 'previous match on cWORD, centered')
-- :jumps shows the window's jump list
nmap('<c-o>', '<c-o>zz', 'next jump entry, centered')
nmap('<c-i>', '<c-i>zz', 'prev jump entry, centered')
-- keep cursor centered when scrolling
nmap('<c-u>', '<c-u>zz', 'scroll upward, centered') -- :h CTRL-u -> scroll window upward
nmap('<c-d>', '<c-d>zz', 'scroll downward, centered') -- scroll window downard
-- navigate splits
nmap('H', ':<c-u>tabprevious<cr>', 'prev TAB')
nmap('L', ':<c-u>tabnext<cr>', 'next TAB')
nmap('<c-j>', '<c-w>j', 'goto window, down')
nmap('<c-k>', '<c-w>k', 'goto window, up')
nmap('<c-l>', '<c-w>l', 'goto window, right')
nmap('<c-h>', '<c-w>h', 'goto window, left')
nmap('<c-p>', '<c-w>p', 'goto window, previous')

-- neoterm
-- nmap("<space>t", ':call ReplStart(expand("<cWORD>"))<cr>', "")
-- nmap("<space>r", ":call ReplRun()<cr>", "")

--[[ leader keys ]]
nmap('<leader>ev', '<cmd>edit ~/.config/nvim/init.lua<cr>', 'edit nvim init.lua')
nmap('<leader>sv', '<cmd>source ~/.config/nvim/init.lua<cr>', 'source nvim init.lua')
nmap('<leader><leader>x', ':lua PKG_RELOAD()<cr>', 'reload package of current buffer')
nmap('<leader><leader>X', '<cmd>write|source %<cr>', 'save & source buffer')
nmap('<space>x', ':lua Vim_run_cmd()<cr>', 'run a vim cmd (`:cmd ..`) on current line')
nmap('<space>X', ':lua Vim_run_cmd({insert=true})<cr>', 'run a vim cmd (`:cmd ..`) and insert result')

--[[ DEBUGGING ]]
nmap('<F8>', "<cmd>lua require'dap'.toggle_breakpoint()<CR>", 'toggle breakpoint')
nmap('<S-F8>', "<Cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", 'set breakpoint')
nmap('<F9>', "<cmd>lua require'dap'.continue()<CR>", 'debug, continue')
nmap('<F10>', "<cmd>lua require'dap'.step_over()<CR>", 'debug, step over')
nmap('<S-F10>', "<cmd>lua require'dap'.step_into()<CR>", 'debug, step into')

-- F11/F12 toggle terminal stuff, so neovim won't see those.
nmap('<S-F11>', "<cmd>lua require'dap'.step_out()<CR>", 'debug, step out')
nmap('<S-F12>', "<cmd>lua require'dap.ui.widgets'.hover()<cr>", 'debug, hover')
nmap(
  '<leader>lp',
  "<cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>",
  'debug, set breakpoint'
)
nmap('<leader>dr', "<Cmd>lua require'dap'.repl.open()<CR>", 'debug, open repl')
nmap('<leader>dl', "<Cmd>lua require'dap'.run_last()<CR>", 'debug, run last')

--[[ development ]]

nmap('<leader>rs', ":lua require('pdh.rfc').search({'rfc', 'std', 'bcp'})<cr>", "find ietf RFC/STD/BCP's")
