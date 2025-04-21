local util = require('navigator.util')
local lsphelper = require('navigator.lspwrapper')
local gui = require('navigator.gui')
local M = {}
-- local location = require('guihua.location')
local partial = util.partial
local locations_to_items = lsphelper.locations_to_items
local log = util.log
-- dataformat should be same as reference
local function location_handler(err, locations, ctx, _, msg)
  if err ~= nil then
    vim.notify('ERROR: ' .. tostring(err) .. ' ' .. msg, vim.log.levels.WARN)
    return
  end
  return locations_to_items(locations, ctx)
end

local function implementation_handler(err, result, ctx, cfg)
  local results = location_handler(err, result, ctx, cfg, 'Implementation not found')
  local ft = vim.api.nvim_get_option_value('ft', { buf = ctx.bufnr })
  gui.new_list_view({ items = results, ft = ft, api = 'Implementation', title = 'Implementation' })
end

function M.implementation(bang, opts)
  if not lsphelper.check_capabilities('implementationProvider') then
    return
  end

  local params = util.make_position_params()
  log('impel params', params)

  lsphelper.call_sync(
    'textDocument/implementation',
    params,
    opts,
    implementation_handler
  )
end

M.implementation_handler = implementation_handler

return M
