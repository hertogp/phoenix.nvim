---
author: me
date: today
---

# nvim configuration

- [ ] one
- [x] two
- [x] three
- [-] four


# TODO:


- [ ] clean up old plugins (incl docs)
- [!] fix it so we can push repo again (git remote set-url origin git@github.com:hertogp/nvim.git)
- [!] important
- [-] install neovim from source
- [-] install neovim from source
- [c] cancelled, strikethrough
- [c] use packer plugin manager
- [x] automatic formatting lua - do not have one-line funcs perse.
- [x] automatic formatting on save for lua
- [x] change to luasnip instead of ultisnips (see: https://www.youtube.com/watch?v=h4g0m0Iwmysc)
- [x] get an outliner for code files/markdown etc..
- [x] get rid of these workspace 'luassert' config questions!
- [x] go all lua config
- [x] install neovim via AppCenter
- [x] install neovim via AppCenter
- [x] nice statusline
- [x] nice statusline - get repo name in there - FugitiveGitDir on BufReadPort, BufileNew -> set bo.git_repo=... and use that in statusline.
- [x] redo Show (in tab) command in lua
- [x] remove fugitive? Not using it anymore
- [x] space-l to search current buffer lines
- [x] understand tree-sitter better
- [x] use language servers for lua, elixir
- [x] use lazy.nvim package manager
- [x] use stylua to format lua code, not luarock's lua-format (does weird things with tables)
- [x] use telescope

## Different types of tables
abc def
--- ---
 x   y
 z   a

|abc|def|
|:-:|:-:|
|a|b|
|c|d|
|e|f|


## Different types of checkmarks

- [ ] todo
- [!] important
- [-] ongoing
- [c] cancelled
- [x] done


this is a subsection

Again another one
=================

Another section diff style
--------------------------

# (section (atx_heading (atx_h1_marker) heading_content: (inline (inline))) ...
body of this heading

### (section (atx_heading (atx_h3_marker) heading_content: (inline (inline))) ...


/home/pdh/.local/share/nvim/mason/bin/bash-language-server


```
~/.config/nvim


.
├── after
│   └── compiler
│       └── pandoc.vim
├── colors
│   ├── darkocean.vim
│   ├── dwarklord.vim
│   ├── lucius.vim
│   ├── solarized.vim
│   ├── twilight256.vim
│   ├── wombat.vim
│   └── xoria256.vim
├── init.lua
├── lazy-lock.json
├── lua
│   ├── config
│   │   ├── autocmds.lua
│   │   ├── colors.lua
│   │   ├── globals.lua
│   │   ├── keymaps.lua
│   │   ├── lazy.lua
│   │   └── options.lua
│   ├── pdh
│   │   ├── outline.lua
│   │   └── telescope.lua
│   ├── plugins
│   │   ├── aerial.lua
│   │   ├── colorschemes.lua
│   │   ├── lspconfig.lua
│   │   ├── lualine.lua
│   │   ├── nvim-web-devicons.lua
│   │   ├── others.lua
│   │   ├── outline.lua
│   │   ├── stylua.lua
│   │   ├── telescope.lua
│   │   ├── tgpg.lua
│   │   └── treesitter.lua
│   └── setup -- moveto: plugin specs
│       ├── comment-setup.lua
│       ├── dap-setup.lua
│       ├── lsp-setup.lua
│       ├── luasnip-setup.lua
│       ├── nvim-cmp-setup.lua
│       └── telescope-setup.lua
├── luasnippets
│   ├── all.lua
│   ├── import.lua
│   └── lua.lua
├── plugin
│   └── voomify.vim.org
├── _readme.pdh.md
├── stylua.toml
└── yarn.lock
```

