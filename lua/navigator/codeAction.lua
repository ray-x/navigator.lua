local util = require "navigator.util"
local log = util.log
local trace = util.trace
local code_action = {}
local gui = require "navigator.gui"
local config = require("navigator").config_values()
local api = vim.api
code_action.code_action_handler = util.mk_handler(function(err, actions, ctx, cfg)
  log(actions, ctx)
  if actions == nil or vim.tbl_isempty(actions) then
    print("No code actions available")
    return
  end
  local data = {"   Auto Fix  <C-o> Apply <C-e> Exit"}
  for i, action in ipairs(actions) do
    local title = action.title:gsub("\r\n", "\\r\\n")
    title = title:gsub("\n", "\\n")
    title = string.format("[%d] %s", i, title)
    table.insert(data, title)
    actions[i].display_title = title
  end
  local width = 0
  for _, str in ipairs(data) do
    if #str > width then
      width = #str
    end
  end

  local apply = require('navigator.lspwrapper').apply_action
  local function apply_action(action)
    local action_chosen = nil
    for key, value in pairs(actions) do
      if value.display_title == action then
        action_chosen = value
      end
    end

    if action_chosen == nil then
      log("no match for ", action, actions)
      return
    end
    apply(action_chosen)
  end

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
end)

-- https://github.com/glepnir/lspsaga.nvim/blob/main/lua/lspsaga/codeaction.lua
-- lspsaga has a clever design to inject code action indicator
local sign_group = "nvcodeaction"
local get_namespace = function()
  return api.nvim_create_namespace(sign_group)
end

local get_current_winid = function()
  return api.nvim_get_current_win()
end

local sign_name = "NavigatorLightBulb"

if vim.tbl_isempty(vim.fn.sign_getdefined(sign_name)) then
  vim.fn.sign_define(sign_name,
                     {text = config.icons.code_action_icon, texthl = "LspDiagnosticsSignHint"})
end

local function _update_virtual_text(line)
  local namespace = get_namespace()
  pcall(api.nvim_buf_clear_namespace, 0, namespace, 0, -1)

  if line then
    local icon_with_indent = "  " .. config.icons.code_action_icon

    pcall(api.nvim_buf_set_extmark, 0, namespace, line, -1, {
      virt_text = {{icon_with_indent, "LspDiagnosticsSignHint"}},
      virt_text_pos = "overlay",
      hl_mode = "combine"
    })
  end
end

local function _update_sign(line)
  local winid = get_current_winid()
  if code_action[winid] == nil then
    code_action[winid] = {}
  end
  if code_action[winid].lightbulb_line ~= 0 then
    vim.fn.sign_unplace(sign_group, {id = code_action[winid].lightbulb_line, buffer = "%"})
  end

  if line then
    -- log("updatasign", line, sign_group, sign_name)
    vim.fn.sign_place(line, sign_group, sign_name, "%",
                      {lnum = line + 1, priority = config.code_action_prompt.sign_priority})
    code_action[winid].lightbulb_line = line
  end
end

local need_check_diagnostic = {["go"] = true, ["python"] = true}

function code_action:render_action_virtual_text(line, diagnostics)
  return function(_, _, actions)
    if actions == nil or type(actions) ~= "table" or vim.tbl_isempty(actions) then
      if config.code_action_prompt.virtual_text then
        _update_virtual_text(nil)
      end
      if config.code_action_prompt.sign then
        _update_sign(nil)
      end
    else
      if config.code_action_prompt.sign then
        if need_check_diagnostic[vim.bo.filetype] then
          if next(diagnostics) == nil then
            _update_sign(nil)
          else
            _update_sign(line)
          end
        else
          _update_sign(line)
        end
      end

      if config.code_action_prompt.virtual_text then
        if need_check_diagnostic[vim.bo.filetype] then
          if next(diagnostics) == nil then
            _update_virtual_text(nil)
          else
            _update_virtual_text(line)
          end
        else
          _update_virtual_text(line)
        end
      end
    end
  end
end

local special_buffers = {
  ["LspSagaCodecode_action"] = true,
  ["lspsagafinder"] = true,
  ["NvimTree"] = true,
  ["vista"] = true,
  ["guihua"] = true,
  ["lspinfo"] = true,
  ["markdown"] = true,
  ["text"] = true
}
-- local action_call_back = function (_,_)
--   return Action:action_callback()
-- end

local action_virtual_call_back = function(line, diagnostics)
  return code_action:render_action_virtual_text(line, diagnostics)
end

local code_action_req = function(_call_back_fn, diagnostics)
  local context = {diagnostics = diagnostics}
  local params = vim.lsp.util.make_range_params()
  params.context = context
  local line = params.range.start.line
  local callback = _call_back_fn(line, diagnostics)
  vim.lsp.buf_request(0, "textDocument/codeAction", params, callback)
end

-- code_action.code_action = function()
--   local diagnostics = vim.lsp.diagnostic.get_line_diagnostics()
--   code_action_req(action_call_back, diagnostics)
-- end

code_action.code_action_prompt = function()
  if special_buffers[vim.bo.filetype] then
    return
  end

  local diagnostics = vim.lsp.diagnostic.get_line_diagnostics()
  local winid = get_current_winid()
  code_action[winid] = code_action[winid] or {}
  code_action[winid].lightbulb_line = code_action[winid].lightbulb_line or 0
  code_action_req(action_virtual_call_back, diagnostics)
end

return code_action
