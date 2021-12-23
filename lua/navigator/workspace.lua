-- https://github.com/lukas-reineke/dotfiles/blob/master/vim/lua/lsp/rename.lua
local M = {}
local util = require('navigator.util')
-- local rename_prompt = 'Rename -> '

M.add_workspace_folder = function()
  util.log(vim.ui.input)
  local input = require('guihua.floating').input
  input({ prompt = 'Workspace To Add: ', default = vim.fn.expand('%:p:h') }, function(inputs)
    util.log(inputs)
    vim.lsp.buf.add_workspace_folder(inputs)
  end)
end

M.remove_workspace_folder = function()
  local select = require('guihua.gui').select
  local folders = vim.lsp.buf.list_workspace_folders()

  if #folders > 1 then
    select(folders, { prompt = 'select workspace to delete' }, function(workspace)
      util.log(workspace)
      vim.lsp.buf.remove_workspace_folder(workspace)
    end)
  end
end

M.workspace_symbol = function()
  local input = vim.ui.input

  vim.ui.input = require('guihua.floating').input
  vim.lsp.buf.workspace_symbol()
  vim.defer_fn(function()
    vim.ui.input = input
  end, 1000)
end

M.list_workspace_folders = function()
  local folders = vim.lsp.buf.list_workspace_folders()
  if #folders > 0 then
    return require('navigator.gui').new_list_view({
      items = folders,
      border = 'single',
      rawdata = true,
      on_move = function(...) end,
    })
  end
end

return M
