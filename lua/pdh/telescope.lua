-- File: ~/.config/nvim/lua/pdh/telescope.lua

--[[ USAGE
 fzf is installed and in the search prompt, you can do:
 asdf   -- fuzzy search                   includes items with those letters
 'asdf  -- exact match                    includes items with asdf exactly
 ^asdf  -- prefix-exact match             includes items that start with asdf
 asdf$  -- suffix-exact match             includes items that end with asdf
 !asdf  -- inverse-exact-match            excludes with asdf exactly
 !^asdf -- inverse-prefix-exact-match     excludes items that start with asdf
 !asdf$ -- inverse-suffix-exact-match     excludes items that end with asdf
 CAPS   -- is an exact-match
]]

local uv = require "luv"

--[[ Header ]]

local action_state = require "telescope.actions.state"
local actions = require "telescope.actions"

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local sorters = require "telescope.sorters"
local previewers = require "telescope.previewers"

-- local config = require("telescope.config").values
local M = {}

--[[ Helpers ]]

local function filter_buf_lines(bufnr, words)
  -- match lines on any of the words and return a list of {linenr, line}
  -- for lines that matched.
  local ok, lines = pcall(function()
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end)

  if not ok or #lines == 0 then
    return {}
  end

  words = words or {}
  local matches = {}
  local linenr = 0
  for _, line in ipairs(lines) do
    for _, word in ipairs(words) do
      if string.find(line, word) then
        matches[#matches + 1] = { linenr, line }
        goto next
      end
    end
    ::next::
    linenr = linenr + 1
  end
  return matches
end

--[[ OUTLINE HELPERS ]]
-- see ~/.local/share/nvim/site/pack/packer/start/nvim-treesitter/queries
-- Notes:
-- - these queries should yield nodes at some level below the root node.
-- - see allowed depth per language in outline_ft_ts_depth table.
-- - only captures named "head" are added (if not too deep in the tree),
-- - the first line of the node is added to the outline
-- - a line is added only once by checking the linenr of the previous entry
--   `-> because subcaptures like "@x" show up as their own captured node ...
local outline_ft_ts_query = {
  markdown = [[
    (section (atx_heading) @head)
    (setext_heading (paragraph) @head)
  ]],

  lua = [[
    ((comment) @head (#lua-match? @head "^--%[%[[^\n]+%]%]$"))
    ((function_declaration) @head)
    ((assignment_statement) @head)
    ((variable_declaration) @head)
    ]],

  -- see https://github.com/elixir-lang/tree-sitter-elixir/tree/main/queries
  elixir = [[
    ((comment) @head (#lua-match? @head "^[%s#]+%[%[[^\n]+%]%]$"))
    (((call (identifier) @x) (#any-of? @x "defmodule" "use" "alias" "def" "defp")) @head)
    (((unary_operator (call (identifier) @h)) @head) (#not-any-of? @h "spec" "doc" "moduledoc"))
  ]],
}

local outline_ft_ts_depth = {
  markdown = 6, -- allow 6 levels deep
  lua = 1, -- means nodes are directly below the root node
  elixir = 2, -- means node must be child of root or module-node
}

local function outline_depth(node, root)
  -- how deep is node relative to root?
  local depth = 0
  local p = node:parent()
  while p and p ~= root do
    depth = depth + 1
    p = p:parent()
  end
  return depth
end

local function outline_lines(bufnr)
  -- return a list of {linenr, text} based on a filetype specific TS query
  local ft = vim.bo[bufnr].filetype
  local max_depth = outline_ft_ts_depth[ft] or 0
  local qry = outline_ft_ts_query[ft]
  if qry == nil then
    vim.notify("[WARN] unsupported filetype: " .. ft, vim.log.levels.WARN)
    return {}
  end

  local query = vim.treesitter.query.parse(ft, qry)
  local parser = vim.treesitter.get_parser(bufnr, ft, {})
  local tree = parser:parse()
  local root = tree[1]:root()

  local results = {}
  for id, node, _ in query:iter_captures(root, 0, 0, -1) do
    local depth = outline_depth(node, root)
    local capture = query.captures[id]

    local linenr = node:range() -- ignore start_col, end_row, end_col
    local prev_line = (results[#results] or { -1 })[1] -- use -1 when results is still empty
    if depth <= max_depth and capture == "head" and linenr ~= prev_line then
      local text = vim.treesitter.get_node_text(node, bufnr)
      text = string.gsub(text, "[\r\n].*", "", 1)
      -- P {"lines", lines}
      if #text > 0 then
        results[#results + 1] = { linenr, text }
      end
    end
  end
  -- P {"results", results}
  return results
end

local function outline_finder(results)
  return finders.new_table {
    results = results,
    entry_maker = function(entry)
      return {
        value = entry,
        display = entry[2],
        ordinal = entry[2],
      }
    end,
  }
end

local outline_previewer = function(src_bufnr)
  return previewers.new_buffer_previewer {
    setup = function(self)
      -- FIXME: BUG: despite the docs, my (table of) vars are not accessible in self
      -- see https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/previewers/buffer_previewer.lua#L319
      self.state = { oops = true }
      return { src_bufnr = vim.api.nvim_get_current_buf() }
    end,
    get_buffer_by_name = function(self, _)
      -- TODO: check caching works, do not grok the docs :he telescope, :3377
      -- especially the mention of entry.your_unique_id ...
      return tostring(self) -- "table 0x..."
    end,
    define_preview = function(self, entry, status)
      -- entry is {display = text, index = nr, ordinal = sort_idx, value {lineno, text} }
      if vim.api.nvim_buf_line_count(self.state.bufnr) == 1 then
        -- preview is initially filled with 1 empty string -> { "" }
        local content = vim.api.nvim_buf_get_lines(src_bufnr, 0, -1, false)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, content)
        vim.bo[self.state.bufnr].filetype = vim.bo[src_bufnr].filetype
        vim.cmd "sleep 10m" -- give it some time before scrolling, otherwise it won't work?
      end
      local tgtlinenr = entry.value[1]
      local winheight = vim.api.nvim_win_get_height(self.state.winid)
      local toplinenr = vim.fn.line("w0", self.state.winid)
      local direction = tgtlinenr - toplinenr - math.floor(winheight / 2)
      vim.api.nvim_buf_clear_namespace(self.state.bufnr, -1, 0, -1)
      -- NOTE: nvim_buf_add_highlight uses a zero-baed index for line nrs.
      pcall(vim.api.nvim_buf_add_highlight, self.state.bufnr, -1, "Visual", tgtlinenr, 0, -1)
      self.scroll_fn(self, direction)
    end,
  }
end

local function outline_goto_selection(prompt_bufnr)
  -- assumes entry consists of {linenr, line}
  actions.select_default:replace(function()
    actions.close(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if selection then
      local linenr = selection.value[1] + 1
      vim.api.nvim_win_set_cursor(0, { linenr, 0 })
      vim.cmd [[normal z.]]
      -- alternative: vim.api.nvim_feedkeys("z.", "n", false)
    else
      print "nothing selected"
    end
  end)
  return true
end

--[[ OUTLINE ]]

M.find_in_buf = function(opts)
  -- fuzzy find in buffer
  -- note that at moment, the builtin current_buffer_fuzzy_find is broken
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  opts = opts or {}
  pickers
    .new({ sorting_strategy = "ascending" }, {
      prompt_title = "fuzzy find in buffer",
      finder = finders.new_table { results = lines },
      sorter = sorters.get_substr_matcher(),

      attach_mappings = function(prompt_bufnr, _)
        -- ignore 2nd arg which is map function toe create keybindings
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            vim.api.nvim_win_set_cursor(0, { selection.index, 0 })
            vim.cmd [[normal z.]]
            -- vim.api.nvim_feedkeys("z.", "n", false)
          else
            print "nothing selected"
          end
        end)
        return true
      end,
    })
    :find()
end

M.outline = function(opts)
  -- outline file based on treesitter queries for given filetype
  opts = opts or {}
  local src_bufnr = vim.api.nvim_get_current_buf()
  local results = outline_lines(src_bufnr)
  if #results == 0 then
    vim.notify("[info] no outline found", vim.log.levels.INFO)
  else
    opts.prompt_title = "Search outline"
    opts.preview_title = "Preview"
    opts.attach_mappings = outline_goto_selection
    opts.sorter = sorters.get_substr_matcher()
    opts.finder = outline_finder(results)
    opts.previewer = outline_previewer(src_bufnr)
    local picker = pickers.new({ sorting_strategy = "ascending" }, opts)
    picker:find()
  end
end

M.codespell = function(bufnr)
  -- NOTES:
  -- - changes working dir to git repo root directory (if found)
  -- - note sure why it sometimes searches the .git dir and sometimes not?
  -- - use a .codespellrc file in repo root to make it behave project specific.  E.g.
  -- - skip does not tolerate spaces in between the directories (!)
  -- - you'll need to add hidden directories (like .git) as well (!)
  -- - codespell does not honor any .gitignore file present
  --   [codespell]
  --   quiet-level = 7                                    -- disable some warnings
  --   disable-colors = true                              -- just to be safe
  --   skip = .git,logs,tmp,scr,_build,deps   -- project specific
  --   TODO: add keymap in normal mode that applies the suggested correction
  --   TODO: add keymap that does codespell only for current buffer (file)

  local bufonly = bufnr or false
  bufnr = bufnr or 0
  local git = Project_root(bufnr)
  local results = {}
  local on_data = function(_, data)
    if data then
      for _, line in ipairs(data) do
        if #line > 0 then
          results[#results + 1] = line
        end
      end
    end
    return results
  end

  local function on_exit()
    local lines = {}
    for _, line in ipairs(results) do
      local parts = vim.split(line, ":")
      lines[#lines + 1] = { filename = parts[1], lnum = parts[2], text = parts[3] }
    end
    if #lines > 0 then
      vim.fn.setqflist(lines)
      require("telescope.builtin").quickfix()
    else
      vim.notify("[info] codespell found no spelling mistakes", vim.log.levels.INFO)
    end
  end

  local retval
  if bufonly then
    local filename = vim.api.nvim_buf_get_name(0)
    retval = vim.fn.jobstart({ "codespell", filename }, {
      stdout_buffered = true,
      on_stdout = on_data,
      on_exit = on_exit,
    })
  else
    if git ~= nil then
      vim.notify("[info] cwd set to " .. git, vim.log.levels.INFO)
      uv.chdir(git)
    end
    retval = vim.fn.jobstart({ "codespell" }, {
      stdout_buffered = true,
      on_stdout = on_data,
      on_exit = on_exit,
    })
  end

  if retval == 0 then
    vim.notify("[error] invalid arguments to codespell", vim.log.levels.ERROR)
  elseif retval == -1 then
    vim.notify("[error] codespell could not be executed", vim.log.levels.ERROR)
  end
end

M.todos = function(opts)
  -- see https://github.com/nvim-telescope/telescope.nvim/tree/master/lua/telescope/previewers/buffer_previewer.lua#L274
  -- line 274
  opts = opts or {}
  if opts.buffer then
    local src_bufnr = vim.api.nvim_get_current_buf()
    local words = { "TODO:", "FIXME:", "BUG:", "XXX:", "NOTE:", "NOTES:", "INFO:" }
    local results = filter_buf_lines(src_bufnr, words)
    if #results == 0 then
      vim.notify("[info] no todo's found", vim.log.levels.INFO)
    else
      opts.prompt_title = "Search ToDo's v2"
      opts.preview_title = "Preview"
      opts.attach_mappings = outline_goto_selection
      opts.sorter = sorters.get_substr_matcher()
      opts.finder = outline_finder(results)
      opts.previewer = outline_previewer(src_bufnr)
      local picker = pickers.new({ sorting_strategy = "ascending" }, opts)
      picker:find()
    end
  else
    require("telescope.builtin").grep_string {
      search = "TODO:|FIXME:|XXX:|BUG:|NOTES?:|INFO:",
      use_regex = true,
    }
  end
end

M.todos2 = function(opts)
  opts = opts or {}
  opts.prompt_title = "Search TODO's"

  if opts and opts.buffer then
    -- use lvimgrep and the window's location list
    local ok, _ = pcall(function()
      -- /j to not jump, leave that to closing action of telescope
      vim.cmd.lvimgrep([[/\C(FIXME\|TODO\|XXX\|NOTES\?\|INFO):/j]], "%")
    end)
    if ok then
      require("telescope.builtin").loclist {
        prompt_title = "Search TODO's",
        results_title = [[\ TODO, FIXME, XXX /]],
        filename_width = 0,
      }
    else
      vim.notify("[info] no TODO, FIXME or XXX's found", vim.log.levels.INFO)
    end
  else
    require("telescope.builtin").grep_string {
      search = "TODO:|FIXME:|XXX:|BUG:|NOTES?:|INFO:",
      use_regex = true,
    }
  end
end

M.rfc = function(opts)
  -- No lsp for raw txt files, so use lvimgrep & window location list
  opts = opts or {}
  opts.prompt_title = "Search Contents"

  local ok, _ = pcall(function()
    vim.cmd.lvimgrep([[/\v^[0-9\.]+[^\n]+/]], "%")
  end)
  if ok then
    require("telescope.builtin").loclist {
      prompt_title = "Search Contents",
      results_title = "Contents",
      trim_text = true,
      preview_title = "Preview",
      filename_width = 0,
    }
  else
    vim.notify("[info] no contents found", vim.log.levels.INFO)
  end
end

M.buffers = function()
  -- map "d" to function that does nvim_buf_delete
  require("telescope.builtin").buffers {
    attach_mappings = function(prompt_bufnr, map)
      map("n", "d", function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.api.nvim_buf_delete(selection.bufnr, { force = true })
      end)
      return true
    end,
  }
end

M.grep_nvim_src = function()
  -- grep Neovim source using <cword>
  require("telescope.builtin").grep_string {
    results_title = "neovim source code",
    prompt_title = "Search neovim source",
    path_display = { "smart" },
    search = nil,
    search_dirs = {
      "~/installs/neovim/neovim/runtime",
      "~/installs/neovim/neovim/src/nvim",
    },
  }
end

M.find_pkg = function()
  -- find files along packpath
  -- packpath is loooong, too long for the find cmd on the cli
  require("telescope.builtin").find_files {
    results_title = "packages",
    prompt_title = "Search packpath",
    path_display = { "smart" },
    search = nil,
    search_dirs = {
      "~/.local/share/nvim/site/pack/packer/opt",
      "~/.local/share/nvim/site/pack/packer/start",
    },
  }
end

return M
