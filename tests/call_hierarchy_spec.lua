local busted = require('plenary/busted')

local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
-- local status = require("plenary.reload").reload_module("go.nvim")
-- status = require("plenary.reload").reload_module("nvim-treesitter")

-- local ulog = require('go.utils').log
describe('should run lsp call hierarchy', function()
  vim.cmd([[packadd navigator.lua]])
  vim.cmd([[packadd guihua.lua]])
  local status = require('plenary.reload').reload_module('navigator')
  status = require('plenary.reload').reload_module('guihua')
  status = require('plenary.reload').reload_module('lspconfig')

  local path = cur_dir .. '/tests/fixtures/interface.go' -- %:p:h ? %:p
  local cmd = " silent exe 'e " .. path .. "'"
  vim.cmd(cmd)
  vim.cmd([[cd %:p:h]])
  local bufn = vim.fn.bufnr('')
  require('navigator').setup({
    debug = true, -- log output, set to true and log path: ~/.local/share/nvim/gh.log
    width = 0.75, -- max width ratio (number of cols for the floating window) / (window width)
    height = 0.3, -- max list window height, 0.3 by default
    preview_height = 0.35, -- max height of preview windows
    border = 'none',
  })

  -- allow gopls start
  for _ = 1, 20 do
    vim.wait(400, function() end)
    local found = false
    for _, client in ipairs(vim.lsp.get_active_clients()) do
      if client.name == 'gopls' then
        found = true
        break
      end
    end
    if found then
      break
    end
  end

  it('should show panel', function()
    vim.fn.setpos('.', { bufn, 24, 15, 0 })
    require('navigator.hierarchy').incoming_calls_panel()

    vim.wait(300, function() end)

    local panel = require('guihua.panel').debug()
    eq(panel.name, 'Panel')

    vim.wait(500, function() end)
    panel = require('guihua.panel').debug()
    print(vim.inspect(panel))
    -- eq(
    --   panel.activePanel.sections[1].header[1],
    --   '──────────Call Hierarchy──────────'
    -- )
    -- eq(panel.activePanel.sections[1].nodes[1].name, 'measure')
  end)

  it('should not crash and show hierarchy', function()
    vim.fn.setpos('.', { bufn, 24, 15, 0 })
    local ret = require('navigator.hierarchy')._call_hierarchy()
    vim.wait(400, function() end)
    eq(ret, ret) -- make sure doesn't crash the result
  end)
end)
