-- https://github.com/nvim-telescope/telescope.nvim

return {

  -- { 'nvim-lua/plenary.nvim' },

  { -- prerequisite: sudo apt install ripgrep fd-find fzf

    'nvim-telescope/telescope.nvim',

    enabled = false,

    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' },

    -- keys = {
    --   -- misc
    --   -- { '<space>c', ":lua require'pdh.telescope'.codespell(0)<cr>", desc = 'codespell buffer' },
    --   -- { '<space>C', ":lua require'pdh.telescope'.codespell()<cr>", desc = 'codespell project' },
    -- },
  },

  { -- https://github.com/nvim-telescope/telescope-fzf-native.nvim
    -- prerequisites
    --  sudo apt install cmake cmake-doc cmake-format
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release',
    enabled = false,
  },

  { --https://github.com/nvim-telescope/telescope-file-browser
    -- see https://www.youtube.com/watch?v=nQIJghSU9TU&list=RDLV-InmtHhk2qM&index=5
    'nvim-telescope/telescope-file-browser.nvim',
    enabled = false,
  },

  { -- https://github.com/crispgm/telescope-heading.nvim
    'crispgm/telescope-heading.nvim',
    enabled = false,
  },
}
