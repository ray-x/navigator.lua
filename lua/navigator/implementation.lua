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

local function implementation_handler(_, err, result, ctx, cfg)
  local results = location_handler(err, result, ctx, cfg, 'Implementation not found')
  local ft = vim.api.nvim_buf_get_option(ctx.bufnr or 0, 'ft')
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
    partial(implementation_handler, bang)
  )
end

M.implementation_call = partial(M.implementation, 0)

M.implementation_handler = partial(implementation_handler, 0)

return M
