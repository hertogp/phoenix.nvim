-- https://github.com/williamboman/mason-lspconfig.nvim
--> bridges mason.nvim with nvim-lspconfig
return {
  'williamboman/mason-lspconfig.nvim',
  ensure_installed = { 'lua_ls' },
}
