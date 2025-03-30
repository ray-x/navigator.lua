local util = require('navigator.util')
local log = util.log
local trace = util.trace
local code_action = {}
-- local gui = require('navigator.gui')
local config = require('navigator').config_values()
local api = vim.api

local sign_name = 'NavigatorLightBulb'

--- `codeAction/resolve`
-- from neovim buf.lua, change vim.ui.select to gui

local diagnostic = vim.diagnostic or vim.lsp.diagnostic

-- https://github.com/glepnir/lspsaga.nvim/blob/main/lua/lspsaga/codeaction.lua
-- lspsaga has a clever design to inject code action indicator
local sign_group = 'nvcodeaction'
local get_namespace = function()
  return api.nvim_create_namespace(sign_group)
end

local get_current_winid = function()
  return api.nvim_get_current_win()
end

local function _update_virtual_text(line, actions)
  local namespace = get_namespace()
  pcall(api.nvim_buf_clear_namespace, 0, namespace, 0, -1)
  local bufnr = api.nvim_get_current_buf()
  api.nvim_buf_del_extmark(bufnr, namespace, 1)

  if line then
    trace(line, actions)
    local icon_with_indent = '  ' .. config.icons.code_action_icon

    local title = actions[1].title
    pcall(api.nvim_buf_set_extmark, 0, namespace, line, -1, {
      virt_text = { { icon_with_indent .. title, 'DiagnosticsSignHint' } },
      hl_mode = 'combine',
    })
  end
end

local function _update_sign(line)
  if vim.tbl_isempty(vim.fn.sign_getdefined(sign_name)) then
    vim.fn.sign_define(sign_name, {
      text = config.icons.code_action_icon,
      texthl = 'DiagnosticsSignHint',
    })
  end
  local winid = get_current_winid()
  if code_action[winid] == nil then
    code_action[winid] = {}
  end
  -- only show code action on the current line, remove all others
  if code_action[winid].lightbulb_line and code_action[winid].lightbulb_line > 0 then
    vim.fn.sign_unplace(sign_group, { id = code_action[winid].lightbulb_line, buffer = '%' })

    trace('sign removed', line)
  end

  if line then
    -- log("updatasign", line, sign_group, sign_name)
    local id = vim.fn.sign_place(
      line,
      sign_group,
      sign_name,
      '%',
      { lnum = line + 1, priority = config.lsp.code_action.sign_priority }
    )
    code_action[winid].lightbulb_line = id
    log('sign updated', id, line, sign_group, sign_name)
  end
end

-- local need_check_diagnostic = {["go"] = true, ["python"] = true}
local need_check_diagnostic = { ['python'] = true }

function code_action:render_action_virtual_text(line, diagnostics)
  return function(err, actions, context)
    trace(actions, context)
    if context and context.client_id then
      local cname = vim.lsp.get_clients({ id = context.client_id })[1].name
      if cname == 'null-ls' and _NgConfigValues.lsp.disable_nulls_codeaction_sign then
        return
      end
    end
    -- if nul-ls enabled, some of the lsp may not send valid code action,
    if actions == nil or type(actions) ~= 'table' or vim.tbl_isempty(actions) then
      -- no actions cleanup
      if config.lsp.code_action.virtual_text then
        _update_virtual_text()
      end
      if config.lsp.code_action.sign then
        _update_sign()
      end
    else
      trace(err, line, diagnostics, actions, context)

      if config.lsp.code_action.sign then
        if need_check_diagnostic[vim.bo.filetype] and next(diagnostics) == nil then
          -- no diagnostic, no code action sign..
          _update_sign()
        else
          _update_sign(line)
        end
      end

      if not config.lsp.code_action.virtual_text then
        return
      end
      if need_check_diagnostic[vim.bo.filetype] and not next(diagnostics) then
        _update_virtual_text()
      else
        _update_virtual_text(line, actions)
      end
    end

    vim.defer_fn(function()
      trace('clear vt')
      if config.lsp.code_action.virtual_text then
        _update_virtual_text(nil)
      end
      if config.lsp.code_action.sign then
        _update_sign(nil)
      end
    end, _NgConfigValues.lsp.code_action.delay)
  end
end

local special_buffers = {
  ['lspsagafinder'] = true,
  ['NvimTree'] = true,
  ['vista'] = true,
  ['guihua'] = true,
  ['lspinfo'] = true,
  ['markdown'] = true,
  ['text'] = true,
}

local action_virtual_call_back = function(line, diagnostics)
  return code_action:render_action_virtual_text(line, diagnostics)
end

local code_action_req = function(_call_back_fn, client, context)
  local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
  params.context = context
  local line = params.range.start.line
  local callback = _call_back_fn(line, context.diagnostics)
  client.request('textDocument/codeAction', params, callback, bufnr)

end

local function sort_select(action_tuples, opts, on_user_choice)
  if action_tuples ~= nil and action_tuples[1][2] ~= nil and action_tuples[1][2].command then
    table.sort(action_tuples, function(a, b)
      return a[1] > b[1]
    end)
  end

  opts.width = config.width
  trace(action_tuples)
  require('guihua.gui').select(action_tuples, opts, on_user_choice)
end

code_action.code_action = function()
  local original_select = vim.ui.select
  vim.ui.select = sort_select
  local mode = vim.api.nvim_get_mode().mode
  local context
  if mode == 'n' or mode == 'i' then
    context = {}
    context.diagnostics = vim.lsp.diagnostic.get_line_diagnostics()
    -- if there are diagnostics, we should fix it first
    if next(context.diagnostics) == nil then
      context = nil
    end
  end

  vim.lsp.buf.code_action({ context = context })
  vim.defer_fn(function()
    vim.ui.select = original_select
  end, 1000)
end

code_action.code_action_prompt = function(client, bufnr, only)
  bufnr = bufnr or api.nvim_get_current_buf()
  only = only or {}
  if special_buffers[vim.bo.filetype] then
    log('skip buffer', vim.bo.filetype)
    return
  end

  local diagnostics
  if diagnostic.get_line_diagnostics then
    -- old version
    diagnostics = diagnostic.get_line_diagnostics()
  else
    local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
    diagnostics = diagnostic.get(vim.api.nvim_get_current_buf(), { lnum = lnum })
  end

  local context = {
    diagnostics = diagnostics,
  }

  if next(only) then
    context.only = only
  end

  log('using code action context for prompt', context)

  local winid = get_current_winid()
  code_action[winid] = code_action[winid] or {}
  code_action[winid].lightbulb_line = code_action[winid].lightbulb_line or 0
  code_action_req(action_virtual_call_back, client, context)
end

return code_action
