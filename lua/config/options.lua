-- https://github.com/nvim-lua/kickstart.nvim  (good place to start with options)

local o = vim.o -- namespace for buffer/window options

-- haven't used this in a while, might need to check the order of the dirs listed
o.path = o.path .. "/snap/bin,./include,/usr/include/linux,/usr/include/x86_64-linux-gnu,/usr/local/include"

o.autowrite = true -- save before commands like :next and :make
o.backspace = "indent,eol,start"
o.background = "dark"
o.cmdheight = 2
o.complete = ".,w,b,u,t,k" -- see :h E535
o.cursorline = true -- defined by your colorscheme plugin
o.formatoptions = "tcrqn2j"
o.guicursor = ""
o.history = 50
o.hlsearch = true
o.ignorecase = true
o.incsearch = true
o.laststatus = 2
o.lazyredraw = true
o.mouse = "a"
o.number = true
o.numberwidth = 4
o.ruler = true
o.shortmess = o.shortmess .. "c"
o.showcmd = true
o.showmatch = true
o.showmode = false -- mode already shown in statusline
o.scrolloff = 5 -- min num of lines above/below the cursorline
o.sidescroll = 10
o.signcolumn = "yes" -- always show signcolumn even if empty
o.smartcase = true -- case sensitive is using uppercase in search
o.splitright = true -- new split always to the right
o.splitbelow = true -- new split always to the bottom
o.termguicolors = true
o.textwidth = 79 -- some filetypes override this
o.undofile = false -- store undo's between sessions
o.updatetime = 300
o.whichwrap = "b,s,<,>,[,]"
o.wildmenu = true
o.wildmode = "longest,list:longest,full"
o.wrap = false

-- indent & tabs
vim.opt.autoindent = true -- keep indentation same as line above
vim.opt.smartindent = true
vim.opt.tabstop = 2 -- a tab shows as 2 spaces
vim.opt.softtabstop = 2 -- insert 2 spaces when pressing <tab>
vim.opt.expandtab = true -- use spaces, not real tab: use C-v<tab> for an actual tab

o.shiftwidth = 2

-- color column
vim.fn.matchadd("ColorColumn", "\\%81v", 100)

-- clipboard
o.clipboard = "unnamed,unnamedplus" -- register * for yanking, + for all y,d,c&p operations
o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
-- o.listchars = "tab:→\\ ,trail:∘,precedes:◀,extends:▶"
o.splitright = true
o.splitbelow = true
