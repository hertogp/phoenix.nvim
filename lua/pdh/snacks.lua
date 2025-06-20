-- simple finders to peruse with a snacks picker

local M = {}

--- run codespell on buffer or directory, fill qflist and run snacks.qflist()
--- @param bufnr? number buffer number
function M.codespell(bufnr)
  -- codespell works on the file on disk, so for any unsaved buffer, the line nrs may be off
  -- see keymaps for nmap's <space>c (buffer) and <space>C (dir)
  -- testcase: succesful ==> successful
  local target = vim.api.nvim_buf_get_name(bufnr or 0)
  target = bufnr and target or vim.fs.dirname(target)

  local function on_exit(obj)
    local lines = vim.split(obj.stdout, '\n', { trimempty = true })
    local results = {}
    for _, line in ipairs(lines) do
      local parts = vim.split(line, '%s*:%s*')
      results[#results + 1] = { filename = parts[1], lnum = parts[2], text = parts[3] }
    end

    if #results > 0 then
      -- no vim.fn's in 'fast event' context like on_exit callbacks ... apparently
      vim.schedule(function()
        vim.fn.setqflist(results)
        require 'snacks.picker'.qflist()
      end)
    else
      vim.notify('codespell found no spelling errors', vim.log.levels.INFO)
    end
  end

  -- run the cmd
  vim.system({ 'codespell', '-d', target }, { text = true }, on_exit)
end

return M
