local lsp = vim.lsp
local util = lsp.util
local nutils = require('navigator.util')
local api = vim.api
local log = nutils.log
local M = {}

local hover_ns = api.nvim_create_namespace('nvim.lsp.hover_range')
local ms = lsp.protocol.Methods

--- @class vim.lsp.buf.hover.Opts : vim.lsp.util.open_floating_preview.Opts
--- @field silent? boolean

--- @param config? vim.lsp.buf.hover.Opts
function M.hover(config)
  config = config or {}
  config.border = _NgConfigValues.border
  return vim.lsp.buf.hover(config)
end
return M
