-- From the man himself:
-- https://raw.githubusercontent.com/tjdevries/advent-of-nvim/refs/heads/master/nvim/plugin/floaterminal.lua
-- https://www.youtube.com/watch?v=5PIiKDES_wc

-- in terminal press esc twice to go to normal mode
vim.keymap.set('t', '<esc><esc>', '<c-\\><c-n>')

local state = {
  floating = {
    buf = -1,
    win = -1,
  },
}

local function create_floating_window(opts)
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)

  -- calculate the position to center the window
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  -- create a buffer
  local buf = nil
  if vim.api.nvim_buf_is_valid(opts.buf) then
    buf = opts.buf
  else
    buf = vim.api.nvim_create_buf(false, true) -- No file, scratch buffer
  end

  -- define window configuration
  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal', -- No borders or extra UI elements
    border = 'rounded',
    title = ' terminal ',
    title_pos = 'center',
  }

  -- create floating window
  local win = vim.api.nvim_open_win(buf, true, win_config)

  return { buf = buf, win = win }
end

local toggle_terminal = function(args)
  local chdir -- expand before creating floating window(!)
  if args.args == '@prj' then
    -- change working directory to working directory
    chdir = 'cd ' .. Project_root(0) .. '\n'
  elseif args.args == '@buf' then
    -- change working directory to buf dir
    chdir = 'cd ' .. vim.fn.expand('%:p:h') .. '\n'
  else
    chdir = 'cd ' .. vim.fn.expand(args.args) .. '\n'
  end

  if not vim.api.nvim_win_is_valid(state.floating.win) then
    -- expand bufdir *before* create_floating_window
    state.floating = create_floating_window { buf = state.floating.buf }
    -- must be after `create_floating_window`, which sets state.floating.buf
    local bufnr = state.floating.buf

    if vim.bo[bufnr].buftype ~= 'terminal' then
      vim.cmd.terminal()
      vim.cmd.startinsert()
      vim.fn.chansend(vim.b[bufnr].terminal_job_id, chdir)
    end
  else
    vim.api.nvim_win_hide(state.floating.win)
  end
end

-- Create a floating window with default dimensions
vim.api.nvim_create_user_command('Floaterminal', toggle_terminal, { nargs = '*' })
vim.keymap.set({ 'n', 't' }, '<leader>T', ':Floaterminal @buf<cr>')
vim.keymap.set({ 'n', 't' }, '<leader>t', ':Floaterminal @prj<cr>')
