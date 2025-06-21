-- simple finders to peruse with a snacks picker

local M = {}

local function codespell_fix(picker, current)
  local items = picker.list.selected
  items = #items > 0 and items or { current }

  for _, item in ipairs(items) do
    if item._codespelled then
      picker.list:unselect(item)
      goto next
    end

    local bufnr = item.item.bufnr
    local lnum = item.item.lnum

    if vim.api.nvim_buf_is_loaded(bufnr) and vim.api.nvim_get_option_value('modifiable', { buf = bufnr }) then
      local old, new = item.item.text:match('(%w+)%s-%S-%s-(%w+)%s*$')
      if old and new then
        local old_line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
        local new_line = old_line:gsub(old, new, 1)
        if new_line ~= old_line then
          vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, { new_line })
          item.line = ('%s -- applied'):format(item.line)
        else
          item.line = ('%s -- skipped (noop: buffer has unsaved changes?)'):format(item.line)
        end
      else
        item.line = ('%s -- not found'):format(item.line)
      end
    elseif vim.api.nvim_get_option_value('modifiable', { buf = bufnr }) then
      item.line = ('%s -- not loaded'):format(item.line)
    else
      item.line = ('%s -- not modifiable'):format(item.line)
    end

    item._codespelled = true -- don't touch item again
    picker.list.dirty = true
    picker.list:unselect(item)
    picker.list:render()
    picker.preview:refresh(picker)

    ::next::
  end
end

--- run codespell on buffer or directory, fill qflist and run snacks.qflist()
--- @param bufnr? number buffer number, if `nil` codespell buffer's directory
function M.codespell(bufnr)
  -- notes:
  -- * codespell is external and checks the files on disk, not buffer contents
  --   => buffers with unsaved changes may be off in linenrs
  -- * keymaps.lua sets <space>c/C to codespell current buffer file/directory
  -- * testcase: successful ==> successful
  local target = vim.api.nvim_buf_get_name(bufnr or 0)
  target = bufnr and target or vim.fs.dirname(target) -- a file or a directory

  local function on_exit(obj)
    local lines = vim.split(obj.stdout, '\n', { trimempty = true })
    local results = {}
    for _, line in ipairs(lines) do
      local parts = vim.split(line, '%s*:%s*')
      results[#results + 1] = { filename = parts[1], lnum = parts[2], text = parts[3], type = 'w' }
    end

    if #results > 0 then
      -- on_exit is a 'fast event' context -> schedule vim.fn.xxx
      vim.schedule(function()
        vim.fn.setqflist(results)
        require 'snacks.picker'.qflist({
          win = {
            input = { keys = { ['f'] = { 'codespell_fix', mode = { 'n' } } } },
            list = { keys = { ['f'] = { 'codespell_fix', mode = { 'n' } } } },
          },
          actions = { codespell_fix = codespell_fix },
        })
      end)
    else
      vim.notify('codespell found no spelling errors', vim.log.levels.INFO)
    end
  end

  -- run the cmd
  vim.system({ 'codespell', '-d', target }, { text = true }, on_exit)
end

return M
