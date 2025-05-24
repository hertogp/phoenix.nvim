-- https://github.com/williamboman/mason-lspconfig.nvi
--> bridges mason.nvim with nvim-lspconfig
return {
  'williamboman/mason-lspconfig.nvim',
  ensure_installed = { 'lua_ls' },
}
