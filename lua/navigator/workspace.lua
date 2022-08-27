-- https://github.com/lukas-reineke/dotfiles/blob/master/vim/lua/lsp/rename.lua
local M = {}
local util = require('navigator.util')
local gutil = require('guihua.util')
local lsphelper = require('navigator.lspwrapper')
local symbols_to_items = lsphelper.symbols_to_items
local vfn = vim.fn

M.add_workspace_folder = function()
  util.log(vim.ui.input)
  local input = require('guihua.floating').input
  input({ prompt = 'Workspace To Add: ', default = vfn.expand('%:p:h') }, function(inputs)
    vim.lsp.buf.add_workspace_folder(inputs)
  end)
end

M.remove_workspace_folder = function()
  local select = require('guihua.gui').select
  local folders = vim.lsp.buf.list_workspace_folders()

  if #folders > 1 then
    return select(folders, { prompt = 'select workspace to delete' }, function(workspace)
      vim.lsp.buf.remove_workspace_folder(workspace)
    end)
  end
end

M.workspace_symbol = function()
  local input = require('guihua.floating').input
  input({ prompt = 'Search symbol: ', default = '' }, function(inputs)
    util.log(inputs)
    vim.lsp.buf.workspace_symbol(inputs)
  end)
end

function M.workspace_symbol_live()
  local height = _NgConfigValues.height or 0.4
  height = math.floor(height * vfn.winheight('%'))
  local width = _NgConfigValues.width or 0.7
  width = math.floor(vim.api.nvim_get_option('columns') * width)
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.o.ft
  local data = { { text = 'input the symbol name to start fuzzy search' } }
  for _ = 1, height do
    table.insert(data, { text = '' })
  end
  local ListView = require('guihua.listview')
  local opt = {
    api = ' ',
    bg = 'GuihuaListDark',
    data = data,
    items = data,
    enter = true,
    ft = ft,
    loc = 'top_center',
    transparency = 50,
    prompt = true,
    on_confirm = function(item)
      vim.defer_fn(function()
        if item and item.name then
          require('navigator.symbols').workspace_symbols(item.name)
        end
      end, 10)
    end,
    on_input_filter = function(text)
      local params = { query = text or '#' }
      local results = vim.lsp.buf_request_sync(bufnr, 'workspace/symbol', params)
      local result
      for _, r in pairs(results) do
        -- util.log(r)
        if r.result then
          result = r.result
          break
        end
      end
      if not result then
        result = {}
      end

      local items = symbols_to_items(result)
      items = gutil.dedup(items, 'name', 'kind')
      return items
    end,
    rect = { height = height, pos_x = 0, pos_y = 0, width = width },
  }

  local win = ListView:new(opt)
  win:on_draw({})
  -- require('guihua.gui').new_list_view(opt)
end

M.list_workspace_folders = function()
  local folders = vim.lsp.buf.list_workspace_folders()
  if #folders > 0 then
    return require('navigator.gui').new_list_view({
      items = folders,
      border = 'single',
      rawdata = true,
      on_move = function() end,
    })
  end
end

return M
