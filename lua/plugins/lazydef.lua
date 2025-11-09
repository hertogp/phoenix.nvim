-- `:Open https://github.com/folke/lazydev.nvim`
-- see blink-cmp.lua where lazydev is added in opts.providers as a provider

return {
  {
    'folke/lazydev.nvim',
    ft = 'lua', -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
        -- not sure how to get it to recognize busted
        -- `:Show !ls.files ~/.local busted luassert pandoc`
        -- `:Show !ls.files ~/.luarocks busted luassert pandoc`
        { path = '${3rd}/busted/library', words = { 'describe', 'it' } },
        { path = '${3rd}/luassert/library', words = { 'assert' } },
        { path = 'snacks.nvim', words = { 'Snacks' } },
        { path = '~/.luarocks/lib/lua/5.4/' }, -- contains .so files
        { path = '~/.luarocks/share/lua/5.4' }, -- installed 5.4 rocks
      },
    },
  },
}
