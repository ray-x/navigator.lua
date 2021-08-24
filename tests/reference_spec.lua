local helpers = {}
local busted = require("plenary/busted")

local eq = assert.are.same
local cur_dir = vim.fn.expand("%:p:h")
-- local status = require("plenary.reload").reload_module("go.nvim")
-- status = require("plenary.reload").reload_module("nvim-treesitter")

-- local ulog = require('go.utils').log
describe("should run lsp reference", function()
  -- vim.fn.readfile('minimal.vim')
  -- vim.fn.writefile(vim.fn.readfile('fixtures/fmt/hello.go'), name)
  -- status = require("plenary.reload").reload_module("go.nvim")
  it("should show references", function()

    local status = require("plenary.reload").reload_module("navigator")
    local status = require("plenary.reload").reload_module("guihua")

    vim.cmd([[packadd navigator.lua]])
    vim.cmd([[packadd guihua.lua]])
    local path = cur_dir .. "/tests/fixtures/interface.go" -- %:p:h ? %:p
    local cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)
    vim.cmd([[cd %:p:h]])
    local bufn = vim.fn.bufnr("")
    require'navigator'.setup({
      debug = false, -- log output, set to true and log path: ~/.local/share/nvim/gh.log
      code_action_icon = "A ",
      width = 0.75, -- max width ratio (number of cols for the floating window) / (window width)
      height = 0.3, -- max list window height, 0.3 by default
      preview_height = 0.35, -- max height of preview windows
      border = 'none'
    })
    -- allow gopls start
    vim.wait(200, function()
    end)
    local clients = vim.lsp.get_active_clients()
    print(vim.inspect(clients))
    vim.wait(200, function()
    end)

    clients = vim.lsp.get_active_clients()
    print(vim.inspect(clients))

    vim.fn.setpos(".", {bufn, 15, 4, 0}) -- width

    vim.bo.filetype = "go"
    vim.lsp.buf.references()
    eq(1, 1)
  end)
  it("reference handler should return items", function()

    local status = require("plenary.reload").reload_module("navigator")
    local status = require("plenary.reload").reload_module("guihua")
    vim.cmd([[packadd navigator.lua]])
    vim.cmd([[packadd guihua.lua]])
    local path = cur_dir .. "/tests/fixtures/interface.go" -- %:p:h ? %:p
    print(path)
    local cmd = " silent exe 'e " .. path .. "'"
    vim.cmd(cmd)
    vim.cmd([[cd %:p:h]])
    local bufn = vim.fn.bufnr("")

    vim.fn.setpos(".", {bufn, 15, 4, 0}) -- width

    vim.bo.filetype = "go"
    require'navigator'.setup({
      debug = false, -- log output, set to true and log path: ~/.local/share/nvim/gh.log
      code_action_icon = "A ",
      width = 0.75, -- max width ratio (number of cols for the floating window) / (window width)
      height = 0.3, -- max list window height, 0.3 by default
      preview_height = 0.35, -- max height of preview windows
      border = 'none'
    })

    -- allow gopls start
    vim.wait(200, function()
    end)
    local result = {
      {
        range = {['end'] = {character = 6, line = 14}, start = {character = 1, line = 14}},
        uri = "file://" .. cur_dir .. "/tests/fixtures/interface.go"
      }, {
        range = {['end'] = {character = 15, line = 24}, start = {character = 10, line = 24}},
        uri = "file://" .. cur_dir .. "/tests/fixtures/interface.go"
      }, {
        range = {['end'] = {character = 17, line = 28}, start = {character = 12, line = 28}},
        uri = "file://" .. cur_dir .. "/tests/fixtures/interface.go"
      }, {
        range = {['end'] = {character = 19, line = 51}, start = {character = 14, line = 51}},
        uri = "file://" .. cur_dir .. "/tests/fixtures/interface.go"
      }, {
        range = {['end'] = {character = 19, line = 55}, start = {character = 14, line = 55}},
        uri = "file://" .. cur_dir .. "/tests/fixtures/interface.go"
      }, {
        range = {['end'] = {character = 16, line = 59}, start = {character = 11, line = 59}},

        uri = "file://" .. cur_dir .. "/tests/fixtures/interface.go"
      }, {
        range = {['end'] = {character = 16, line = 5}, start = {character = 11, line = 5}},
        uri = "file://" .. cur_dir .. "/tests/fixtures/interface_test.go"
      }
    }
    local win, items, width = require('navigator.reference').reference_handler(nil,
                                                                               "textDocument/references",
                                                                               result, 1, 1)
    eq(win.ctrl.data[1].display_filename, "./interface.go")
    eq(win.ctrl.data[2].range.start.line, 14)
    eq(items[1].display_filename, "./interface.go")
    eq(width, 60)
  end)
end)
