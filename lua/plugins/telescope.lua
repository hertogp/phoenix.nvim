-- https://github.com/nvim-telescope/telescope.nvim

return {

  { "nvim-lua/plenary.nvim" },

  { -- prerequisite: sudo apt install ripgrep fd-find fzf
 
    "nvim-telescope/telescope.nvim",

    tag = '0.1.8',
    dependencies = { "nvim-lua/plenary.nvim" },

    keys = {
      -- misc
      -- { "<space><space>", ":Telescope resume<cr>", desc = "resume last telescope"},
      -- { "<space>d", ":Telescope diagnostics<cr>", desc = "telescope diagnostics"},
      -- { "<space>e", ":Telescope diagnostics<cr>", desc = "telescope diagnostics"},
      { "<space>c", ":lua require'pdh.telescope'.codespell(0)<cr>", desc = "codespell buffer"},
      { "<space>C", ":lua require'pdh.telescope'.codespell()<cr>", desc = "codespell project"},
      -- {"<space>t", ':lua require"pdh.telescope".todos({buffer=true})<cr>', desc = "search buf ToDo's"},
      -- {"<space>T", ':lua require"pdh.telescope".todos({})<cr>', desc="search proj ToDo's"},

      -- outlines
      {"<space>o", ":lua require'pdh.outline'.toggle()<cr>", desc = "toggle outline"},
      -- {"<space>O", ":AerialToggle<cr>", desc = "toggle Aerial outline"},

      {"<space>m", ":Telescope heading<cr>", desc = "telescope headings"},
      -- {"<space>s", ":Telescope lsp_document_symbols<cr>", desc = "telescope doc symbols"},

      -- grep files
      -- { "<space>g", ":Telescope grep_string<cr>", desc = "grep word under cursor"},
      -- { "<space>G", ":Telescope live_grep<cr>", desc = "grep interactive"},

      -- {"<space>l", "<cmd>lua require'pdh.telescope'.find_in_buf()<cr>", desc = "find in buffer"},
      -- {"<space>L", function()
           -- You can pass additional configuration to telescope to change theme, layout, etc.
      --     require("telescope.builtin").current_buffer_fuzzy_find(
      --         require("telescope.themes").get_dropdown { winblend = 10, previewer = false })
      --     end, { desc = "[/] Fuzzily search in current buffer]" }},

      -- find files
      -- { "<space>f", ":lua require 'telescope.builtin'.find_files({hidden=true, cwd=Project_root()})<cr>", desc = "search proj dir for files"},
      -- { "<space>F", ":lua require 'telescope.builtin'.find_files({hidden=true, cwd=vim.fn.expand('%:p:h')})<cr>", desc = "search files from bufdir"},
--      { "<space>n", ":lua require 'telescope.builtin'.find_files({search_dirs={'~/notes'}, search_file='md'})<cr>", desc = "search note files"},

      -- buffers, quickfix & window location list
      -- {"<space>b", ":Telescope buffers sort_lastused=true<cr>", desc = "pick from buffers"},
      -- {"<space>B", ':lua require"telescope.builtin".buffers({hidden=true, show_all_buffers=true,  sort_mru=true})<cr>', desc = "pick from *all* buffers"},
      -- {"<space>q", ":Telescope quickfix<cr>", desc = "quickfix"},
      -- {"<space>w", ":Telescope loclist<cr>", desc = "window location list"},

      -- help
      -- {"<space>h", ":Telescope help_tags<cr>", desc = "search neovim help"},
      -- {"<space>H", ":Telescope builtin<cr>", desc = "search telescope builtin's"},
      -- {"<space>M", ':Telescope man_pages sections={"ALL"}<cr>', desc = "man pages"},
      -- {"<space>k", ":Telescope keymaps<cr>", desc = "search keymaps"},

    }
  },

  { -- https://github.com/nvim-telescope/telescope-fzf-native.nvim
    -- prerequisites
    --  sudo apt install cmake cmake-doc cmake-format
    'nvim-telescope/telescope-fzf-native.nvim', 
    build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release'
  },

  { --https://github.com/nvim-telescope/telescope-file-browser
    -- see https://www.youtube.com/watch?v=nQIJghSU9TU&list=RDLV-InmtHhk2qM&index=5
    "nvim-telescope/telescope-file-browser.nvim"
  },

  { -- https://github.com/crispgm/telescope-heading.nvim
    "crispgm/telescope-heading.nvim"
  }


}