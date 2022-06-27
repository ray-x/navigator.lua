local util = require('navigator.util')
local log = util.log
local trace = util.trace

local event_hdlrs = {
  { ev = 'BufWritePre', func = [[require "navigator.diagnostics".set_diag_loclist()]] },
  { ev = 'CursorHold', func = 'document_highlight()' },
  { ev = 'CursorHoldI', func = 'document_highlight()' },
  { ev = 'CursorMoved', func = 'clear_references()' },
}

if vim.lsp.buf.format == nil then
  vim.lsp.buf.format = vim.lsp.buf.formatting
end

if vim.diagnostic == nil then
  util.error('Please update nvim to 0.6.1+')
end
local double = { '╔', '═', '╗', '║', '╝', '═', '╚', '║' }
local single = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' }
-- TODO https://github.com/neovim/neovim/pull/16591 use vimkeymap.set/del
-- LuaFormatter off
local key_maps = {
  { key = 'gr', func = "require('navigator.reference').async_ref()" },
  { key = '<Leader>gr', func = "require('navigator.reference').reference()" }, -- reference deprecated
  { mode = 'i', key = '<M-k>', func = 'signature_help()' },
  { key = '<c-k>', func = 'signature_help()' },
  { key = 'g0', func = "require('navigator.symbols').document_symbols()" },
  { key = 'gW', func = "require('navigator.workspace').workspace_symbol_live()" },
  { key = '<c-]>', func = "require('navigator.definition').definition()" },
  { key = 'gd', func = "require('navigator.definition').definition()" },
  { key = 'gD', func = "declaration({ border = 'rounded', max_width = 80 })" },
  { key = 'gp', func = "require('navigator.definition').definition_preview()" },
  { key = '<Leader>gt', func = "require('navigator.treesitter').buf_ts()" },
  { key = '<Leader>gT', func = "require('navigator.treesitter').bufs_ts()" },
  { key = '<Leader>ct', func = "require('navigator.ctags').ctags()" },
  { key = 'K', func = 'hover({ popup_opts = { border = single, max_width = 80 }})' },
  { key = '<Space>ca', mode = 'n', func = "require('navigator.codeAction').code_action()" },
  { key = '<Space>ca', mode = 'v', func = "require('navigator.codeAction').range_code_action()" },
  -- { key = '<Leader>re', func = 'rename()' },
  { key = '<Space>rn', func = "require('navigator.rename').rename()" },
  { key = '<Leader>gi', func = 'incoming_calls()' },
  { key = '<Leader>go', func = 'outgoing_calls()' },
  { key = 'gi', func = 'implementation()' },
  { key = '<Space>D', func = 'type_definition()' },
  { key = 'gL', func = "require('navigator.diagnostics').show_diagnostics()" },
  { key = 'gG', func = "require('navigator.diagnostics').show_buf_diagnostics()" },
  { key = '<Leader>dt', func = "require('navigator.diagnostics').toggle_diagnostics()" },
  { key = ']d', func = "diagnostic.goto_next({ border = 'rounded', max_width = 80})" },
  { key = '[d', func = "diagnostic.goto_prev({ border = 'rounded', max_width = 80})" },
  { key = ']O', func = 'diagnostic.set_loclist()' },
  { key = ']r', func = "require('navigator.treesitter').goto_next_usage()" },
  { key = '[r', func = "require('navigator.treesitter').goto_previous_usage()" },
  { key = '<C-LeftMouse>', func = 'definition()' },
  { key = 'g<LeftMouse>', func = 'implementation()' },
  { key = '<Leader>k', func = "require('navigator.dochighlight').hi_symbol()" },
  { key = '<Space>wa', func = "require('navigator.workspace').add_workspace_folder()" },
  { key = '<Space>wr', func = "require('navigator.workspace').remove_workspace_folder()" },
  { key = '<Space>ff', func = 'format({async = true})', mode = 'n' },
  { key = '<Space>ff', func = 'range_formatting()', mode = 'v' },
  { key = '<Space>wl', func = "require('navigator.workspace').list_workspace_folders()" },
  { key = '<Space>la', mode = 'n', func = "require('navigator.codelens').run_action()" },
}

local commands = {
  [[command!  -nargs=* Nctags lua require("navigator.ctags").ctags(<f-args>)]],
  "command! -nargs=0 LspLog lua require'navigator.lspclient.config'.open_lsp_log()",
  "command! -nargs=0 LspRestart lua require'navigator.lspclient.config'.reload_lsp()",
  "command! -nargs=0 LspToggleFmt lua require'navigator.lspclient.mapping'.toggle_lspformat()<CR>",
  "command! -nargs=0 LspKeymaps lua require'navigator.lspclient.mapping'.get_keymaps_help()<CR>",
  "command! -nargs=0 LspSymbols lua require'navigator.symbols'.side_panel()<CR>",
  "command! -nargs=0 TSymbols lua require'navigator.treesitter'.side_panel()<CR>",
  "command! -nargs=* Calltree lua require'navigator.hierarchy'.calltree(<f-args>)<CR>",
}

local key_maps_help = {}
-- LuaFormatter on
local M = {}

local ccls_mappings = {
  { key = '<Leader>gi', func = "require('navigator.cclshierarchy').incoming_calls()" },
  { key = '<Leader>go', func = "require('navigator.cclshierarchy').outgoing_calls()" },
}

local check_cap = function(opts)
  -- log(vim.lsp.buf_get_clients(0))
  local fmt, rfmt, ccls
  local cap = opts.cap
  if cap == nil then
    if opts.client and opts.client.server_capabilities then
      cap = opts.client.server_capabilities
    end
  end
  if cap and cap.documentFormattingProvider then
    fmt = true
  end
  if cap and cap.documentRangeFormattingProvider then
    rfmt = true
  end
  for _, value in pairs(vim.lsp.buf_get_clients(0)) do
    trace(value)
    if value ~= nil and value.server_capabilities == nil then
      if value.server_capabilities.documentFormattingProvider then
        fmt = true
      end
      if value.server_capabilities.documentRangeFormattingProvider then
        rfmt = true
      end

      log('override ccls', value.config)
      if value.config.name == 'ccls' then
        ccls = true
      end
    end
  end
  return fmt, rfmt, ccls
end

local function set_cmds(_)
  for _, value in pairs(commands) do
    vim.cmd(value)
  end
end

local function set_mapping(lsp_info)
  local opts = { noremap = true, silent = true }
  lsp_info = lsp_info or {}
  log('setup mapping', lsp_info.client.name, lsp_info.client.cmd)
  local user_key = _NgConfigValues.keymaps or {}
  local bufnr = lsp_info.bufnr or 0

  local function del_keymap(...)
    vim.api.nvim_buf_del_keymap(bufnr, ...)
  end

  local function set_keymap(...)
    vim.api.nvim_buf_set_keymap(bufnr, ...)
  end
  -- local function buf_set_option(...)
  --   vim.api.nvim_buf_set_option(bufnr, ...)
  -- end
  local doc_fmt, range_fmt, ccls = check_cap(lsp_info)

  if ccls then
    vim.list_extend(key_maps, ccls_mappings)
  end

  if _NgConfigValues.default_mapping ~= false then
    for _, v in pairs(user_key) do
      trace('binding', v)
      local exists = false
      for _, default in pairs(key_maps) do
        if v.func == default.func and (v.mode or 'n') == (default.mode or 'n') and not default.override then
          default.key, default.override, exists = v.key, true, true
          break
        end
      end
      if not exists then
        table.insert(key_maps, v)
      end
    end
  else
    key_maps = _NgConfigValues.keymaps or {}
    log('setting maps to ', key_maps)
  end
  local fmtkey, rfmtkey
  for _, value in pairs(key_maps) do
    local f = '<Cmd>lua vim.lsp.buf.' .. value.func .. '<CR>'
    if string.find(value.func, 'require') or string.find(value.func, 'vim.') then
      f = '<Cmd>lua ' .. value.func .. '<CR>'
    elseif string.find(value.func, 'diagnostic') then
      local diagnostic = '<Cmd>lua vim.'
      diagnostic = '<Cmd>lua vim.'
      f = diagnostic .. value.func .. '<CR>'
      -- elseif string.find(value.func, 'vim.') then
      --   f = '<Cmd>lua ' .. value.func .. '<string.find(value.func, 'vim.')CR>'
    end
    local k = value.key
    local m = value.mode or 'n'
    if string.find(value.func, 'range_formatting') then
      rfmtkey = value.key
    elseif string.find(value.func, 'format') then
      fmtkey = value.key
    end
    trace('binding', k, f)
    set_keymap(m, k, f, opts)
  end

  for _, val in pairs(key_maps) do
    table.insert(key_maps_help, (val.mode or 'n') .. '|' .. val.key .. '|' .. val.func)
  end

  -- if user_opts.cap.document_formatting then

  if doc_fmt and _NgConfigValues.lsp.format_on_save then
    vim.cmd([[
      aug NavigatorAuFormat
        au!
        autocmd BufWritePre <buffer> lua vim.lsp.buf.format({async = true})
      aug END
     ]])
  elseif fmtkey then
    del_keymap('n', fmtkey)
  end

  if lsp_info.cap and lsp_info.cap.document_range_formatting then
    log('formatting enabled', lsp_info.cap)
  end

  if not range_fmt and rfmtkey then
    del_keymap('v', rfmtkey)
  end

  log('enable format ', doc_fmt, range_fmt, _NgConfigValues.lsp.format_on_save)
end

local function autocmd()
  vim.api.nvim_exec(
    [[
            aug NavigatorDocHlAu
                au!
                au CmdlineLeave : lua require('navigator.dochighlight').cmd_nohl()
            aug END
        ]],
    false
  )
end

local function set_event_handler(user_opts)
  user_opts = user_opts or {}
  local file_types =
    'c,cpp,h,go,python,vim,sh,javascript,html,css,lua,typescript,rust,javascriptreact,typescriptreact,kotlin,php,dart,nim,java'
  -- local format_files = "c,cpp,h,go,python,vim,javascript,typescript" --html,css,
  vim.api.nvim_command([[augroup nvim_nv_lsp_autos]])
  vim.api.nvim_command([[autocmd!]])

  for _, value in pairs(event_hdlrs) do
    local f = ''
    if string.find(value.func, 'require') ~= nil then
      f = 'lua ' .. value.func
    else
      f = 'lua vim.lsp.buf.' .. value.func
    end
    local cmd = 'autocmd FileType '
      .. file_types
      .. ' autocmd nvim_nv_lsp_autos '
      .. value.ev
      .. ' <buffer> silent! '
      .. f
    vim.api.nvim_command(cmd)
  end
  vim.api.nvim_command([[augroup END]])
end

M.toggle_lspformat = function(on)
  if on == nil then
    _NgConfigValues.lsp.format_on_save = not _NgConfigValues.lsp.format_on_save
  else
    _NgConfigValues.lsp.format_on_save = on
  end
  if _NgConfigValues.lsp.format_on_save then
    if on == nil then
      vim.notify('format on save true', vim.lsp.log_levels.INFO)
    end
    vim.cmd([[set eventignore-=BufWritePre]])
  else
    if on == nil then
      vim.notify('format on save false', vim.lsp.log_levels.INFO)
    end
    vim.cmd([[set eventignore+=BufWritePre]])
  end
end

function M.setup(user_opts)
  user_opts = user_opts or _NgConfigValues
  set_mapping(user_opts)
  set_cmds(user_opts)

  autocmd()
  set_event_handler(user_opts)

  local client = user_opts.client or {}
  local cap = client.server_capabilities or vim.lsp.protocol.make_client_capabilities()

  log('lsp cap:', cap.codeActionProvider)

  if cap.call_hierarchy or cap.callHierarchyProvider then
    vim.lsp.handlers['callHierarchy/incomingCalls'] = require('navigator.hierarchy').incoming_calls_handler
    vim.lsp.handlers['callHierarchy/outgoingCalls'] = require('navigator.hierarchy').outgoing_calls_handler
  end

  vim.lsp.handlers['textDocument/references'] = require('navigator.reference').reference_handler
  -- vim.lsp.handlers["textDocument/codeAction"] = require"navigator.codeAction".code_action_handler
  vim.lsp.handlers['textDocument/definition'] = require('navigator.definition').definition_handler

  if cap.declarationProvider then
    vim.lsp.handlers['textDocument/declaration'] = require('navigator.definition').declaration_handler
  end

  vim.lsp.handlers['textDocument/typeDefinition'] = require('navigator.definition').typeDefinition_handler
  vim.lsp.handlers['textDocument/implementation'] = require('navigator.implementation').implementation_handler

  -- vim.lsp.handlers['textDocument/documentSymbol'] = require('navigator.symbols').document_symbol_handler
  vim.lsp.handlers['workspace/symbol'] = require('navigator.symbols').workspace_symbol_handler
  vim.lsp.handlers['textDocument/publishDiagnostics'] = require('navigator.diagnostics').diagnostic_handler

  -- TODO: when active signature merge to neovim, remove this setup:

  if
    _NgConfigValues.signature_help_cfg and #_NgConfigValues.signature_help_cfg > 0 or _NgConfigValues.lsp_signature_help
  then
    log('setup signature from navigator')
    local hassig, sig = pcall(require, 'lsp_signature')
    if hassig then
      sig.setup(_NgConfigValues.signature_help_cfg or {})
    end
  else
    vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(require('navigator.signature').signature_handler, {
      border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
    })
  end

  local border_style = single
  if _NgConfigValues.border == 'double' then
    border_style = double
  end
  vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, { border = border_style })
  if cap.documentFormattingProvider then
    log('formatting enabled setup hdl')
    vim.lsp.handlers['textDocument/formatting'] = require('navigator.formatting').format_hdl
  end
end

M.get_keymaps_help = function()
  local ListView = require('guihua.listview')
  local win = ListView:new({
    loc = 'top_center',
    border = 'none',
    prompt = true,
    enter = true,
    rect = { height = 20, width = 90 },
    data = key_maps_help,
  })

  return win
end

return M
