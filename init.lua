--[[ https://lazy.folke.io/installation

Notes:
- ~/.local/share/nvim/lazy/<plugin>    <- where plugins are installed into (added to runtimepath)
- :echo nvim_list_runtime_paths()      <- see runtimepath
- :echo stdpath("config")              <- see current config dir, see also :h NVIM_APPNAME
- ~/.local/state/nvim/lazy/readme/doc  <- lazy puts plugin readme's here

]]

require 'config.lazy'

-- for some reason, this works here but not in globals.lua ..
vim.api.nvim_set_hl(0, 'WinSeparator', { link = 'Constant', force = true })
vim.api.nvim_set_hl_ns(0)
print('init done!')
-- print('rtp', string.gsub(vim.inspect(vim.opt.rtp), ',/', '\r\n/'))
