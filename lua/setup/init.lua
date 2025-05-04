-- File: ~/.config/nvim/lua/setup/init.lua
-- source all *other* files in this directory.
for file in vim.fs.dir "~/.config/nvim/lua/setup" do
  if file ~= "init.lua" then
    file = string.gsub(file, ".lua$", "")
    require("setup." .. file)
  end
end

