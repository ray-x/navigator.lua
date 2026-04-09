local M = {}

local util = require('navigator.util')
local health = vim.health

local start = health.start
local ok = health.ok
local error = health.error
local warn = health.warn

local function plugin_check()
  start('navigator Plugin Check')

  local plugins = {
    'lspconfig',
    -- 'nvim-treesitter',
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
  if vim.fn.has('nvim-0.12') == 0 then
    error('navigator.nvim requires neovim 0.12+. Neovim 0.11 is no longer supported.')
    return
  end
  plugin_check()
end

return M
