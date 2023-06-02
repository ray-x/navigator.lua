local M = {}

local util = require('navigator.util')
local log = util.log
local health = vim.health
if not vim.health then
  health = require('health')
end

local nvim_09 = vim.fn.has('nvim-0.9') == 1

local start = nvim_09 and health.start or health.report_start
local ok = nvim_09 and health.ok or health.report_ok
local error = nvim_09 and health.error or health.report_error
local warn = nvim_09 and health.warn or health.report_warn
local info = nvim_09 and health.info or health.report_info

local vfn = vim.fn

local function plugin_check()
  start('navigator Plugin Check')

  local plugins = {
    'lspconfig',
    'nvim-treesitter',
    'guihua',
  }
  local any_warn = false
  local ts_installed = false
  for _, plugin in ipairs(plugins) do
    if pcall(require, plugin) then
      ok(string.format('%s: plugin is installed', plugin))
      if plugin == 'nvim-treesitter' then
        ts_installed = true
      end
    else
      any_warn = true
      warn(string.format('%s: not installed/loaded', plugin))
    end
  end
  if any_warn then
    warn('Not all plugin installed')
  else
    ok('All plugin installed')
  end
end


function M.check()
  if vim.fn.has('nvim-0.9') == 0 then
    warn('Suggested neovim version 0.9 or higher')
  end
  plugin_check()
end

return M
