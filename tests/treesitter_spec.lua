local golden_result = {
  {
    col = 9,
    display_filename = '/tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
    filename = '/tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
    full_text = 'package main',
    kind = '🚀',
    lnum = 1,
    node_scope = {
      ['end'] = {
        character = 0,
        line = 12,
      },
      start = {
        character = 0,
        line = 0,
      },
    },
    node_text = 'main',
    indent = '',
    range = {
      ['end'] = {
        character = 12,
        line = 0,
      },
      start = {
        character = 8,
        line = 0,
      },
    },
    text = ' 🚀 main      \t package main',
    type = 'namespace',
    uri = 'file:///tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
  },
  {
    col = 6,
    display_filename = '/tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
    filename = '/tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
    full_text = 'func interfaceTest()',
    kind = ' ',
    lnum = 5,
    indent = '',
    node_scope = {
      ['end'] = {
        character = 1,
        line = 11,
      },
      start = {
        character = 0,
        line = 4,
      },
    },
    node_text = 'interfaceTest',
    range = {
      ['end'] = {
        character = 18,
        line = 4,
      },
      start = {
        character = 5,
        line = 4,
      },
    },
    text = '   interfaceTest\t func interfaceTest()',
    type = 'function',
    uri = 'file:///tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
  },
  {
    col = 2,
    display_filename = '/tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
    filename = '/tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
    full_text = 'r := rect{width: 3, height: 4}',
    kind = ' ',
    lnum = 6,
    node_scope = {
      ['end'] = {
        character = 1,
        line = 11,
      },
      start = {
        character = 21,
        line = 4,
      },
    },

    indent = '  ',
    node_text = 'r',
    range = {
      ['end'] = {
        character = 2,
        line = 5,
      },
      start = {
        character = 1,
        line = 5,
      },
    },
    text = '      r         \t r := rect{width: 3, height: 4}',
    type = 'var',
    uri = 'file:///tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
  },
  {
    col = 2,
    display_filename = '/tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
    filename = '/tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
    full_text = 'c := circle{radius: 5}',
    kind = ' ',
    lnum = 7,
    node_scope = {
      ['end'] = {
        character = 1,
        line = 11,
      },
      start = {
        character = 21,
        line = 4,
      },
    },
    node_text = 'c',
    indent = '  ',
    range = {
      ['end'] = {
        character = 2,
        line = 6,
      },
      start = {
        character = 1,
        line = 6,
      },
    },
    text = '      c         \t c := circle{radius: 5}',
    type = 'var',
    uri = 'file:///tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
  },
  {
    col = 2,
    display_filename = '/tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
    filename = '/tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
    full_text = 'd := circle{radius: 10}',
    kind = ' ',
    lnum = 10,
    indent = '  ',
    node_scope = {
      ['end'] = {
        character = 1,
        line = 11,
      },
      start = {
        character = 21,
        line = 4,
      },
    },
    node_text = 'd',
    range = {
      ['end'] = {
        character = 2,
        line = 9,
      },
      start = {
        character = 1,
        line = 9,
      },
    },
    text = '      d         \t d := circle{radius: 10}',
    type = 'var',
    uri = 'file:///tmp/github/ray-x/navigator.lua/tests/fixtures/interface_test.go',
  },
}

print(golden_result[1].node_text)

local busted = require('plenary/busted')

local eq = assert.are.same
local cur_dir = vim.fn.expand('%:p:h')
-- local status = require("plenary.reload").reload_module("go.nvim")
-- status = require("plenary.reload").reload_module("nvim-treesitter")

-- local ulog = require('go.utils').log
describe('should run lsp reference', function()
  -- vim.fn.readfile('minimal.vim')
  it('should show ts nodes', function()
    local status = require('plenary.reload').reload_module('navigator')
    local status = require('plenary.reload').reload_module('guihua')
    local status = require('plenary.reload').reload_module('lspconfig')

    vim.cmd([[packadd nvim-lspconfig]])
    vim.cmd([[packadd navigator.lua]])
    vim.cmd([[packadd guihua.lua]])
    vim.cmd([[packadd nvim-treesitter]])
    require('nvim-treesitter.configs').setup({
      ensure_installed = { 'go' },
      sync_install = true,
      highlight = { enable = true },
    })
    local path = cur_dir .. '/tests/fixtures/interface_test.go' -- %:p:h ? %:p
    local cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)
    vim.cmd([[cd %:p:h]])
    local bufn = vim.fn.bufnr('')
    -- require'lspconfig'.gopls.setup {}
    require('navigator').setup({
      debug = true, -- log output, set to true and log path: ~/.local/share/nvim/gh.log
    })

    -- allow gopls start
    for i = 1, 10 do
      vim.wait(400, function() end)
      local clients = vim.lsp.get_clients()
      print('lsp clients: ', #clients)
      if #clients > 0 then
        break
      end
    end

    vim.fn.setpos('.', { bufn, 15, 4, 0 }) -- width

    vim.bo.filetype = 'go'
    local view, items, w = require('navigator.treesitter').buf_ts()
    eq(items[1].node_text, golden_result[1].node_text)
    eq(items[2].node_text, golden_result[2].node_text)
  end)
end)
