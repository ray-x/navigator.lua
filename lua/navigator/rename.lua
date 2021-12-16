-- https://github.com/lukas-reineke/dotfiles/blob/master/vim/lua/lsp/rename.lua
local M = {}
local util = require('navigator.util')
-- local rename_prompt = 'Rename -> '

M.rename = function()
  local input = vim.ui.input

  vim.ui.input = require('guihua.floating').input
  vim.lsp.buf.rename()
  vim.defer_fn(function()
    vim.ui.input = input
  end, 1000)
end

return M
