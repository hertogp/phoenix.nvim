-- https://github.com/hedyhli/outline.nvim

return {
  'hedyhli/outline.nvim',

  config = function()
    -- mapping to toggle outline
    vim.keymap.set('n', '<leader>o', '<cmd>topleft Outline<CR>', { desc = 'Toggle Outline' })

    require('outline').setup {
      -- Your setup opts here (leave empty to use defaults)
      -- position = 'left',
    }
  end,
}
