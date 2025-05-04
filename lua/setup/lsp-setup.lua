-- [[ LUA ]]
-- neodev.vim
-- https://github.com/folke/neodev.nvim
-- setup neodev BEFORE any other lsp
require("neodev").setup {}

-- setup language servers.
-- https://github.com/neovim/nvim-lspconfig
-- generic keymaps
local on_attach = function(client, bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
  vim.keymap.set("n", "E", vim.diagnostic.open_float, opts)
  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
  vim.keymap.set("n", "td", ":Telescope diagnostics<cr>", opts)
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

--[[ MASON ]]
-- https://github.com/williamboman/mason.nvim
-- https://github.com/williamboman/mason-lspconfig.nvim
-- Setup mason so it can manage external tooling
--  Add any additional override configuration in the following tables. They will be passed to
--  the `settings` field of the server config. You must look up that documentation yourself.
local servers = {
  -- clangd = {},
  -- gopls = {},
  -- pyright = {},
  -- rust_analyzer = {},
  -- tsserver = {},
  -- elixirls = {}, -- mason can't download latest version apparently

  sumneko_lua = {
    Lua = {
      diagnostics = { globals = { "vim", "use" } },
      workspace = {

        -- Make the server aware of Neovim runtime files
        -- vim.api.nvim_get_runtime_file('', true)
        library = {
          -- [vim.fn.expand('$XDG_CONFIG_HOME/nvim')] = true,
          [vim.fn.expand "$VIMRUNTIME/lua"] = true,
          [vim.fn.expand "$VIMRUNTIME/lua/vim"] = true,
          -- [vim.fn.stdpath('config') .. '/lua'] = true,
        },
        checkThirdParty = false,
      },
      telemetry = { enable = false },
    },
  },
}

-- https://github.com/williamboman/mason-lspconfig.nvim
require("mason").setup()

-- Ensure the servers above are installed
local mason_lspconfig = require "mason-lspconfig"

mason_lspconfig.setup {
  ensure_installed = vim.tbl_keys(servers),
}

mason_lspconfig.setup_handlers {
  function(server_name)
    require("lspconfig")[server_name].setup {
      capabilities = capabilities,
      on_attach = on_attach,
      settings = servers[server_name],
    }
  end,
}

-- Turn on lsp status information
require("fidget").setup()

-- [[elixir_ls]]
-- https://github.com/elixir-lsp/elixir-ls
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#elixirls
-- https://elixirforum.com/t/elixir-ls-fails-in-neovim/56523/7
-- see ~/.config/lsp/_readme.pdh.md
-- we do not install elixir-ls via Mason
local root_pattern = require("lspconfig").util.root_pattern

require("lspconfig").elixirls.setup {
  filetypes = { "elixir", "eelixir", "heex", "surface" },
  root_dir = root_pattern("mix.exs", ".git") or vim.loop.os_homedir(),
  cmd = { "/home/pdh/.config/lsp/elixir-ls/release/language_server.sh" },
  on_attach = on_attach,
  capabilities = capabilities,
}
-- [[ now handled by mason ]]
--
-- https://github.com/sumneko/lua-language-server
-- https://github.com/sumneko/lua-language-server/wiki/Configuration-File#neovim-with-built-in-lsp-client
-- https://github.com/nvim-lua/kickstart.nvim/blob/master/init.lua (tjdevries' kickstart)
-- local lua_lsp_root = vim.fn.expand "~/.config/lsp/lua-language-server"
-- local runtime_path = vim.split(package.path, ";")
-- table.insert(runtime_path, "lua/?.lua")
-- table.insert(runtime_path, "lua/?/ini.lua")
--
-- require("lspconfig").sumneko_lua.setup {
--   cmd = {
--     vim.fn.expand(lua_lsp_root .. "/bin/lua-language-server"),
--     "-E",
--     lua_lsp_root .. "/main.lua",
--   },
--   on_attach = on_attach,
--   capabilities = capabilities,
-- settings = {
--   Lua = {
--     diagnostics = { globals = { "vim", "use" } },
--     runtime = { version = "Lua 5.1", path = runtime_path },
--     workspace = {
--       -- Make the server aware of Neovim runtime files
--       -- vim.api.nvim_get_runtime_file('', true)
--       library = {
--         -- [vim.fn.expand('$XDG_CONFIG_HOME/nvim')] = true,
--         [vim.fn.expand "$VIMRUNTIME/lua"] = true,
--         [vim.fn.expand "$VIMRUNTIME/lua/nvim/lsp"] = true,
--         -- [vim.fn.stdpath('config') .. '/lua'] = true,
--       },
--       checkThirdParty = false,
--     },
--   },
-- },
-- }

--[[ LUA autoformatting ]]
-- now done with ~/bin/stylua (-> ~/installs/stylua)
-- reason to switch is that lua-format insist on putting tables on 1 row if possible
-- TODO: remove stuff below, no longer needed
-- uses efm-language server in combination with luaformatter
-- https://github.com/mattn/efm-langserver
-- `-> installed in ~/go
-- https://github.com/Koihik/LuaFormatter
-- https://www.chrisatmachine.com/blog/category/neovim/28-neovim-lua-development
-- require'lspconfig'.efm.setup({
--   init_options = {documentFormatting = true},
--   filetypes = {"lua"},
--   settings = {
--     rootMarkers = {".git/"},
--     languages = {
--       lua = {
--         {
--           formatCommand = "lua-format -i --indent-width=2 --no-use-tab --no-keep-simple-control-block-one-line --no-keep-simple-function-one-line --no-break-after-operator --column-limit=150 --break-after-table-lb",
--           formatStdin = true
--         }
--       }
--     }
--   }
-- })
