-- https://github.com/nvim-treesitter/nvim-treesitter

--[[ NOTES
--treesitter-playground plugin is deprecated, use :Inspect, :InspectTree and :EditQuery
- use Inspect or InspectTree to see language construct matched at point of cursor
  these can be used (e.g.) to change highlighting in your colorscheme (if it supports it)
- :TSInstall <language to install>
- nvim-treesitter.setup doesn't take options, must use nvim-treesitter.config.setup(opts)
  hence the config=function() .. end instead of opts={..}
- :echo nvim_get_runtime_file('parser', v:true)  -> should have only 1 parser dir in the list
  see: https://github.com/nvim-treesitter/nvim-treesitter#i-get-query-error-invalid-node-type-at-position



]]
return {

  { -- :TSInstall <language_to_install>

    'nvim-treesitter/nvim-treesitter',

    enabled = true,

    -- build = function()
    --   local ts_update = require("nvim-treesitter.install").update { with_sync = true }
    --   ts_update()
    -- end,

    build = ':TSUpdate',

    keys = {
      { '<space>i', ':Inspect<cr>', desc = 'TS inspect current word' },
      { '<space>I', ':InspectTree<cr>', desc = 'TS toggle tree' },
    },

    config = function()
      local configs = require 'nvim-treesitter.configs'

      configs.setup {
        -- A list of parser names, or "all"
        -- :Inspect, :InspectTree
        ensure_installed = {
          'c',
          'lua',
          'elixir',
          'vim',
          'vimdoc',
          'query',
          'markdown',
          'markdown_inline',
          'html',
        },
        update_strategy = 'do not use lockfile',
        sync_install = false, -- only applied to `ensure_installed`
        auto_install = false, -- we don't have `tree-sitter` CLI installed locally
        ignore_install = { 'javascript' }, -- list of parsers to ignore installing (for "all")

        indent = {
          enable = true,
        },

        highlight = {
          enable = true, -- `false` will disable the whole extension
          additional_vim_regex_highlighting = false,
        },

        query_linter = {
          enable = true,
          use_virtual_text = true,
          lint_events = { 'BufWrite', 'CursorHold' },
        },

        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = '<space><Enter>',
            node_incremental = '<Enter>',
            scope_incremental = false, -- false disables the mapping
            node_decremental = '<Backspace>',
          },
        },

        -- https://github.com/nvim-treesitter/playground
        -- deprecated since it's included in Neovim 0.10+
        --  playground = {
        --    enable = true,
        --    disable = {},
        --    updatetime = 25, -- Debounced time for highlighting nodes in the playground from source code
        --    persist_queries = false, -- don't persist a query across vim sessions
        --    keybindings = {
        --      toggle_query_editor = 'o',
        --      toggle_hl_groups = 'i',
        --      toggle_injected_languages = 't',
        --      toggle_anonymous_nodes = 'a',
        --      toggle_language_display = 'I',
        --      focus_language = 'f',
        --      unfocus_language = 'F',
        --      update = 'R',
        --      goto_node = '<cr>',
        --      show_help = '?',
        --    },
        -- },
      }
    end,
  },
}
