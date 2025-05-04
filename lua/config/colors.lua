-- modify some colors after loading your colorscheme
vim.cmd [[
  augroup ChangeBackgroudColour
    autocmd colorscheme * :hi normal guibg=None
  augroup END
]]

-- override CursorLine background color for 1 or more colorschemes
vim.cmd [[
  augroup ColorScheme
   autocmd colorscheme spacegray :highlight CursorLine guibg=#203040
   autocmd colorscheme spacegray :echomsg "Cursorline fixed!"
  augroup END
]]

vim.cmd [[hi normal guibg=None]]

-- vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#203040' })
-- vim.api.nvim_set_hl(0, "ColorColumn", { ctermbg = "DarkGrey", ctermfg = "white" })
-- vim.api.nvim_set_hl(0,"Pmenu",{ cterm = { italic = true }, ctermfg = "white", ctermbg = "darkgrey" })
-- vim.api.nvim_set_hl(0,"PmenuSel", { cterm = { italic = true }, ctermfg = "white", ctermbg = "darkblue" })
-- vim.api.nvim_set_hl(0, "LineNr", { ctermfg = 239, ctermbg = 234 })
