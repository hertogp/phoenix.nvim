-- https://github.com/wesleimp/stylua.nvim

return {
  -- https://github.com/JohnnyMorganz/StyLua/releases
  -- requires a stylua binary from johnny morganz:
  -- * download stylua-linux-x86_64.zip from releases/ to ~/installs/stylua
  -- * unzip and ln -s ~/installs/stylua/stylua ~/bin/stylua

  'wesleimp/stylua.nvim',
  enabled = false,
  -- in proj/stylua.toml
  --   syntax = "Lua54" # "Lua5.1" for nvim projects
  --   column_width = 120,
  --   line_endings = "Unix",
  --   indent_type = "Spaces",
  --   indent_width = 2,
  --   quote_style = "AutoPreferDouble",
  --   call_parentheses = "Input",
  --   collapse_simple_statement = "Always",
}
