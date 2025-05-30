-- BOOTSTRAP lazy.nvim
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  -- install lazy.nvim plugin -> ~/.local/share/nvim/lazy/lazy.nvim
  -- see :echo stdpath("data")
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

-- before loading lazy.nvim
vim.g.mapleader = ','
vim.g.maplocalleader = '\\'

require 'config.globals' -- global opts and funcs from ~/.config/nvim/lua dir
require 'config.options' -- same for regular options

-- setup the plugins
require('lazy').setup {
  -- https://lazy.folke.io/configuration

  change_detection = {
    enabled = false,
    notify = true,
  },
  spec = { -- https://lazy.folke.io/spec
    { import = 'plugins' },
  },

  install = { colorscheme = { 'kanagawa' } },
  checker = { enabled = true }, -- check for updates
}

-- after loading the plugins
require 'config.keymaps'
require 'config.autocmds'

--[[
TODO: move setup into the plugin spec's, either via:
- opts = {}, which will be provided to <plugin>.setup(opts), or
- config = function() .. end, in case you need to run extra commands
]]

-- replace symbols-outline with aerial
-- require "setup.symbols-outline-setup"
