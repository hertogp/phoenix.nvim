-- https://github.com/neovim/nvim-lspconfig

--[[ NOTES:
- when using snap to install tools being used, add /snap/node/current/bin to $PATH
  * for some reason the symlinks in /snap/bin don't seem to work
  * used for sudo snap install node -> used by Mason when installing e.g. bashls

- prerequisites:
  -  mise install elixir-ls
  -  mise use -g elixir-ls (sets bin path)
  - nb: parts taken from kickstart.nvim

]]

return {

  {
    'neovim/nvim-lspconfig',

    dependencies = {

      -- https://github.com/williamboman/mason.nvim
      --> a package manager for LSP-, DAP-servers, linters and formatters
      { 'williamboman/mason.nvim', opts = {} },

      -- https://github.com/williamboman/mason-lspconfig.nvim
      --> bridges mason.nvim with nvim-lspconfig
      { 'williamboman/mason-lspconfig.nvim', ensure_installed = { 'lua_ls' } },

      -- https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim
      --> install/upgrade all third party tools
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- useful status updates for LSP
      { -- https://github.com/j-hui/fidget.nvim
        --> useful on-screen status updates for LSP
        'j-hui/fidget.nvim',
        opts = {},
      },
    },

    config = function()
      -- LSP's, installed separately from neovim, provide Neovim with features like:
      -- See `:help lsp-vs-treesitter` for the overview & interaction of the two.

      --  This function gets run when an LSP attaches to a particular buffer.
      --    Every time a new file is opened, this function will configure the buffer.
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),

        callback = function(event)
          -- create buffer local keymaps
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          -- https://github.com/ibhagwan/fzf-lua/issues/944
          -- :FzfLua lsp_code_actions previewer=codeaction_native
          -- map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
          -- map('grn', function()
          --   require('fzf-lua').lsp_code_actions { previewer = codeaction_native }
          -- end, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error/warning
          -- map('ca', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          -- Find references for the word under your cursor.
          -- map('grr', require('fzf-lua').lsp_references, '[G]oto [R]eferences')

          -- Jump to the implementation of the word under your cursor.
          -- map('gri', require('fzf-lua').lsp_implementations, '[G]oto [I]mplementation')

          -- Jump to the definition of the word under your cursor, use <C-t> to jump back
          -- map('grd', require('fzf-lua').lsp_definitions, '[G]oto [D]efinition')

          -- Jump to the declaration (not definition!) of word under cursor
          -- map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- Fuzzy find all the symbols in your current document.
          -- map('gO', require('fzf-lua').lsp_document_symbols, '[G] [O]pen Document Symbols')

          -- Fuzzy find all the symbols in your current workspace (i.e. project)
          -- map('gW', require('fzf-lua').lsp_live_workspace_symbols, 'Open Workspace Symbols')

          -- Jump to the type of the word under your cursor.
          --  Useful when you're not sure what type a variable is and you want to see
          --  the definition of its *type*, not where it was *defined*.
          -- map('grt', require('fzf-lua').lsp_typedefs, '[G]oto [T]ype Definition')

          -- This function resolves a difference between neovim nightly (version 0.11) and stable (version 0.10)
          ---@param client vim.lsp.Client
          ---@param method vim.lsp.protocol.Method
          ---@param bufnr? integer some lsp support methods only in specific files
          ---@return boolean
          local function client_supports_method(client, method, bufnr)
            if vim.fn.has 'nvim-0.11' == 1 then
              return client:supports_method(method, bufnr)
            else
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if
            client
            and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf)
          then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })

            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Diagnostic Config
      -- See :help vim.diagnostic.Opts
      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_lines = false,
        virtual_text = {
          -- TODO: prefer virtual lines over virtual text which goes off screen
          -- for longer lines of code (annoying)
          virtual_text = false, -- true/false makes no difference
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add blink.cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with blink.cmp, and then broadcast that to the servers.

      local org_capabilities = vim.lsp.protocol.make_client_capabilities()
      local capabilities = require('blink.cmp').get_lsp_capabilities(org_capabilities)

      -- Enable the following language servers
      --   Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --
      --   Add any additional override configuration in the following tables. Available keys are:
      --     - cmd (table):          Override the default command used to start the server
      --     - filetypes (table):    Override the default list of associated filetypes for the server
      --     - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
      --     - settings (table):     Override the default settings passed when initializing the server.
      --   For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
      --   mrjakob: use Mason to look at new language servers (ctrl-f to filter), then add them here (short name if available)
      local servers = {

        bashls = {
          -- https://github.com/bash-lsp/bash-language-server
          -- sudo snap install bash-language-server --classic  (not required, Mason installs its own version)
          -- sudo snap install npm --classic                   (used by Mason to install some packages)
          -- NOTE: add /snap/node/current/bin to $PATH before /snap/bin (otherwise neovim won't find the right node/npm)
          --   /snap/bin symlinks are cmd's that point to /usr/bin/snap, which uses the name under which it was invoked
          --   as the package/executable to run.  Maybe neovim is following the symlink instead of calling it?  In which
          --   /usr/bin/snap gets called as-is, not under its symlinked name and things fail ...  see also snap alias.

          cmd = { 'bash-language-server', 'start' },
          filetypes = { 'bash', 'sh', 'zsh' },
        },

        -- markdown
        -- https://github.com/artempyanykh/marksman - has code action for inserting toc
        marksman = {},
        -- TODO: https://github.com/jonschlinkert/markdown-toc ?

        -- clangd = {},
        -- gopls = {},
        -- pyright = {},
        -- rust_analyzer = {},
        -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
        --
        -- Some languages (like typescript) have entire language plugins that can be useful:
        --    https://github.com/pmizio/typescript-tools.nvim
        --
        -- But for many setups, the LSP (`ts_ls`) will work just fine
        -- ts_ls = {},
        --

        lua_ls = {
          -- https://github.com/LuaLS/lua-language-server
          -- https://luals.github.io/wiki/

          -- cmd = { ... },
          -- filetypes = { ... },
          -- capabilities = {},
          settings = {
            Lua = {
              --     completion = {
              --       callSnippet = 'Replace',
              --     },
              -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
              diagnostics = {
                disable = { 'missing-fields' },
                globals = { 'vim', 'use', 'Snacks' },
              },
              format = {
                enable = true,
                defaultConfig = {
                  indent_style = 'space',
                  indent_size = 2,
                },
              },
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      --
      -- :Mason -> check status of installed tools and/or manually install other tools
      --   You can press `g?` for help in this menu.
      --
      -- `mason` had to be setup earlier: to configure its options see the
      -- `dependencies` table for `nvim-lspconfig` above.
      --
      -- You can add other tools here that you want Mason to install
      -- for you, so that they are available from within Neovim and will
      -- install automatically when you check out your nvim config on a new
      -- machine.
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format Lua code
        'prettierd', -- Used to format javascript
        'prettier', -- Used to format javascript
      })

      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        ensure_installed = {}, -- explicitly set to an empty table, we install via mason-tool-installer!
        automatic_installation = false,
        automatic_enable = true,
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- This handles overriding only values explicitly passed
            -- by the server configuration above. Useful when disabling
            -- certain features of an LSP (for example, turning off formatting for ts_ls)
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end,
  },
}
