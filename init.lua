--[[ https://lazy.folke.io/installation

 ~/.config/nvim
 ├── lua
 │   ├── config
 │   │   ├── lazy.lua        - bootstrap & run lazy package manager
 |   |   ├── autocmds.lua
 |   |   ├── globals.lua
 |   |   ├── keymaps.lua
 |   |   ├── colors.lua
 │   |   └── options.lua
 |   |
 │   └── plugins             - lazy plugin specifications
 │       ├── spec1.lua       - https://lazy.folke.io/spec
 │       ├── **
 │       └── spec2.lua
 └── init.lua                - nvim's entry point

Notes:
- ~/.local/share/nvim/lazy/<plugin>    <- where plugins are installed into (added to runtimepath)
- :echo nvim_list_runtime_paths()      <- see runtimepath
- :echo stdpath("config")              <- see current config dir, see also :h NVIM_APPNAME
- ~/.local/state/nvim/lazy/readme/doc  <- lazy puts plugin readme's here

]]

require "config.lazy"
local done = function()
  print "done!"
end

done()
