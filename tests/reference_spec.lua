local helpers = {}
local busted = require('plenary/busted')

local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
-- local status = require("plenary.reload").reload_module("go.nvim")
-- status = require("plenary.reload").reload_module("nvim-treesitter")

-- local ulog = require('go.utils').log
describe('should run lsp reference', function()
  -- vim.fn.readfile('minimal.vim')
  local nvim_6 = true
  if debug.getinfo(vim.lsp.handlers.signature_help).nparams > 4 then
    nvim_6 = false
  end
  local result = {
    {
      range = { ['end'] = { character = 6, line = 14 }, start = { character = 1, line = 14 } },
      uri = 'file://' .. cur_dir .. '/tests/fixtures/interface.go',
    },
    {
      range = { ['end'] = { character = 15, line = 24 }, start = { character = 10, line = 24 } },
      uri = 'file://' .. cur_dir .. '/tests/fixtures/interface.go',
    },
    {
      range = { ['end'] = { character = 17, line = 28 }, start = { character = 12, line = 28 } },
      uri = 'file://' .. cur_dir .. '/tests/fixtures/interface.go',
    },
    {
      range = { ['end'] = { character = 19, line = 51 }, start = { character = 14, line = 51 } },
      uri = 'file://' .. cur_dir .. '/tests/fixtures/interface.go',
    },
    {
      range = { ['end'] = { character = 19, line = 55 }, start = { character = 14, line = 55 } },
      uri = 'file://' .. cur_dir .. '/tests/fixtures/interface.go',
    },
    {
      range = { ['end'] = { character = 16, line = 59 }, start = { character = 11, line = 59 } },

      uri = 'file://' .. cur_dir .. '/tests/fixtures/interface.go',
    },
    {
      range = { ['end'] = { character = 16, line = 5 }, start = { character = 11, line = 5 } },
      uri = 'file://' .. cur_dir .. '/tests/fixtures/interface_test.go',
    },
  }
  local status = require('plenary.reload').reload_module('navigator')
  status = require('plenary.reload').reload_module('guihua')
  status = require('plenary.reload').reload_module('lspconfig')

  vim.cmd([[packadd navigator.lua]])
  vim.cmd([[packadd guihua.lua]])
  local path = cur_dir .. '/tests/fixtures/interface.go' -- %:p:h ? %:p
  local cmd = " silent exe 'e " .. path .. "'"
  vim.cmd(cmd)
  vim.cmd([[cd %:p:h]])
  local bufn = vim.fn.bufnr('')
  -- require'lspconfig'.gopls.setup {}
  require('navigator').setup({
    debug = true, -- log output, set to true and log path: ~/.local/share/nvim/gh.log
    icons = { code_action_icon = 'A ' },
    width = 0.75, -- max width ratio (number of cols for the floating window) / (window width)
    height = 0.3, -- max list window height, 0.3 by default
    preview_height = 0.35, -- max height of preview windows
    border = 'none',
  })

  if vim.fn.has('nvim-0.7') then
    _NgConfigValues.treesitter_analysis = true
  else
    _NgConfigValues.treesitter_analysis = false
  end
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
  it('should show references', function()
    vim.fn.setpos('.', { bufn, 15, 4, 0 }) -- width

    vim.bo.filetype = 'go'
    vim.lsp.buf.references()
    eq(1, 1)
  end)
  it('reference handler should return items', function()
    vim.fn.setpos('.', { bufn, 15, 4, 0 }) -- width


    vim.bo.filetype = 'go'
    -- allow gopls start
    vim.wait(200, function() end)

    local win, items, width

    if nvim_6 then
      win, items, width = require('navigator.reference').ref_view(nil, result, {
        method = 'textDocument/references',
        bufnr = 1,
        client_id = 1,
      }, {})
    else
      win, items, width = require('navigator.reference').reference_handler(nil, 'textDocument/references', result, 1, 1)
    end

    -- print('win', vim.inspect(win))
    print('items', vim.inspect(items))
    eq(win.ctrl.data[1].display_filename, './tests/fixtures/interface.go')
    eq(win.ctrl.data[2].range.start.line, 14)
    eq(items[1].display_filename, './tests/fixtures/interface.go')

    -- eq(width, 60)
  end)
  it('reference handler should return items with thread', function()
    vim.wait(200, function() end)

    local win, items, width

    if nvim_6 then
      win, items, width = require('navigator.reference').ref_view(nil, result, {
        method = 'textDocument/references',
        bufnr = 1,
        client_id = 1,
      }, { truncate = 2 })
    else
      win, items, width = require('navigator.reference').reference_handler(nil, 'textDocument/references', result, 1, 1)
    end
    -- print('win', vim.inspect(win))
    print('items', vim.inspect(items))
    -- eq(win.ctrl.data, "./interface.go")
    eq(win.ctrl.data[1].display_filename, './tests/fixtures/interface.go')
    eq(win.ctrl.data[2].range.start.line, 14)
    -- eq(items[1].display_filename, "./interface.go")

    -- eq(width, 60)
  end)
end)
