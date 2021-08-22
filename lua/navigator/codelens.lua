-- codelenses
-- https://github.com/josa42/nvim-lsp-codelenses/blob/master/lua/jg/lsp/codelenses.lua
-- https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/codelens.lua
local codelens = require('vim.lsp.codelens')

local log = require"navigator.util".log

local lsphelper = require "navigator.lspwrapper"
local api = vim.api
local gui = require "navigator.gui"
local M = {}

local config = require("navigator").config_values()
local sign_name = "NavigatorCodeLensLightBulb"
if vim.tbl_isempty(vim.fn.sign_getdefined(sign_name)) then
  vim.fn.sign_define(sign_name,
                     {text = config.icons.code_lens_action_icon, texthl = "LspDiagnosticsSignHint"})
end

local sign_group = "nvcodelensaction"

local get_current_winid = require('navigator.util').get_current_winid

local code_lens_action = {}

local function _update_sign(line)
  log("update sign at line ", line)
  local winid = get_current_winid()
  if code_lens_action[winid] == nil then
    code_lens_action[winid] = {}
  end
  if code_lens_action[winid].lightbulb_line ~= 0 then
    vim.fn.sign_unplace(sign_group, {id = code_lens_action[winid].lightbulb_line, buffer = "%"})
  end

  if line then
    -- log("updatasign", line, sign_group, sign_name)
    vim.fn.sign_place(line, sign_group, sign_name, "%",
                      {lnum = line + 1, priority = config.code_lens_action_prompt.sign_priority})
    code_lens_action[winid].lightbulb_line = line
  end
end

local function codelens_hdlr(err, _, result, client_id, bufnr)
  if err then
    warn("lsp code lens", vim.inspect(err))
    return
  end
  log("codelenes result", result)
  for _, v in pairs(result) do
    _update_sign(v.range.start.line)
  end
end

function M.setup()
  vim.cmd('highlight! link LspCodeLens LspDiagnosticsHint')
  vim.cmd('highlight! link LspCodeLensText LspDiagnosticsInformation')
  vim.cmd('highlight! link LspCodeLensTextSign LspDiagnosticsSignInformation')
  vim.cmd('highlight! link LspCodeLensTextSeparator Boolean')

  vim.cmd('augroup navigator.codelenses')
  vim.cmd('  autocmd!')
  vim.cmd(
      "autocmd BufEnter,CursorHold,InsertLeave <buffer> lua require('navigator.codelens').refresh()")
  vim.cmd('augroup end')
  local on_codelens = vim.lsp.handlers["textDocument/codeLens"]
  vim.lsp.handlers["textDocument/codeLens"] = function(err, _, result, client_id, bufnr)
    on_codelens(err, _, result, client_id, bufnr)
    codelens_hdlr(err, _, result, client_id, bufnr)
  end
end

M.lsp_clients = {}

function M.refresh()
  assert(#vim.lsp.buf_get_clients() > 0, "Must have a client running to use lsp code action")
  if not lsphelper.check_capabilities("code_lens") then
    return
  end
  vim.lsp.codelens.refresh()
end

function M.run_action()
  log("run code len action")

  assert(#vim.lsp.buf_get_clients() > 0, "Must have a client running to use lsp code action")
  if not lsphelper.check_capabilities("code_lens") then
    return
  end

  local line = api.nvim_win_get_cursor(0)[1]
  local bufnr = api.nvim_get_current_buf()

  local lenses = codelens.get(bufnr)
  if lenses == nil or #lenses == 0 then
    return
  end
  local width = 40

  local data = {"   CodeLens Action  <C-o> Apply <C-e> Exit"}
  local idx = 1
  for i, lens in pairs(lenses) do
    if lens.range.start.line == (line - 1) then
      local title = lens.command.title:gsub("\r\n", "\\r\\n")
      title = title:gsub("\n", "\\n")
      title = string.format("[%d] %s", idx, title)
      table.insert(data, title)
      lenses[i].display_title = title
      width = math.max(width, #lens.command.title)
      idx = idx + 1
    end
  end
  local apply = require('navigator.lspwrapper').apply_action
  local function apply_action(action)
    local action_chosen = nil
    for key, value in pairs(lenses) do
      if value.display_title == action then
        action_chosen = value
      end
    end
    if action_chosen == nil then
      log("no match for ", action, lenses)
      return
    end
    apply(action_chosen)
  end
  if #data > 0 then
    gui.new_list_view {
      items = data,
      width = width + 4,
      loc = "top_center",
      relative = "cursor",
      rawdata = true,
      data = data,
      on_confirm = function(pos)
        log(pos)
        apply_action(pos)
      end,
      on_move = function(pos)
        log(pos)
        return pos
      end
    }
  end
end

return M
