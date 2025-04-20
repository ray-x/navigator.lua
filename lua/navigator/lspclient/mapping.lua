local util = require('navigator.util')
local log = util.log
local trace = util.trace
local api = vim.api

if vim.lsp.buf.format == nil then
  vim.lsp.buf.format = vim.lsp.buf.formatting
end

if vim.diagnostic == nil then
  util.error('Please update nvim to 0.6.1+')
end

local function fallback_keymap(key)
  -- when handler failed fallback to key
  vim.schedule(function()
    print('fallback to key', key)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, true, true), 'n', true)
  end)
end

local function fallback_fn(key)
  return function()
    fallback_keymap(key)
  end
end

local remap = util.binding_remap
-- stylua: ignore start
local key_maps = {
  { key = 'gr',            func = require('navigator.reference').async_ref,                             desc = 'async_ref' },
  { key = '<Leader>gr',    func = require('navigator.reference').reference,                             desc = 'reference' }, -- reference deprecated
  { key = '<M-k>',         func = vim.lsp.buf.signature_help,                                           desc = 'signature_help',                    mode = 'i' },
  { key = '<c-k>',         func = vim.lsp.buf.signature_help,                                           desc = 'signature_help' },
  { key = '<Leader>g0',    func = require('navigator.symbols').document_symbols,                        desc = 'document_symbols' },
  { key = 'gW',            func = require('navigator.workspace').workspace_symbol_live,                 desc = 'workspace_symbol_live' },
  { key = '<c-]>',         func = require('navigator.definition').definition,                           desc = 'definition' },
  { key = 'gd',            func = remap(require('navigator.definition').definition, 'gd'),              desc = 'definition' },
  { key = 'gD',            func = vim.lsp.buf.declaration,                                              desc = 'declaration',                       fallback = fallback_fn('gD') }, -- fallback used
  -- for lsp handler
  { key = 'gp',            func = remap(require('navigator.definition').definition_preview, 'gp'),      desc = 'definition_preview' },                                              -- paste
  { key = 'gP',            func = remap(require('navigator.definition').type_definition_preview, 'gP'), desc = 'type_definition_preview' },                                         -- paste
  { key = '<Leader>gt',    func = require('navigator.treesitter').buf_ts,                               desc = 'buf_ts' },
  { key = '<Leader>gT',    func = require('navigator.treesitter').bufs_ts,                              desc = 'bufs_ts' },
  { key = '<Leader>ct',    func = require('navigator.ctags').ctags,                                     desc = 'ctags' },
  { key = '<Space>ca',     func = require('navigator.codeAction').code_action,                          desc = 'code_action',                       mode = { 'n', 'v' } },
  -- { key = '<Leader>re', func = 'rename()' },
  { key = '<Space>rn',     func = require('navigator.rename').rename,                                   desc = 'rename' },
  { key = '<Leader>gi',    func = require('navigator.hierarchy').incoming_calls,                        desc = 'incoming_calls' },
  { key = '<Leader>go',    func = require('navigator.hierarchy').outgoing_calls,                        desc = 'outgoing_calls' },
  { key = 'gi',            func = require('navigator.implementation').implementation_call,              desc = 'implementation',                    fallback = fallback_fn('gi') }, -- insert
  { key = '<Space>D',      func = vim.lsp.buf.type_definition,                                          desc = 'type_definition' },
  { key = 'gL',            func = require('navigator.diagnostics').show_diagnostics,                    desc = 'show_diagnostics' },
  { key = 'gG',            func = require('navigator.diagnostics').show_buf_diagnostics,                desc = 'show_buf_diagnostics' },
  { key = '<Leader>dt',    func = require('navigator.diagnostics').toggle_diagnostics,                  desc = 'toggle_diagnostics' },
  { key = ']d',            func = require('navigator.diagnostics').goto_next,                           desc = 'next diagnostics error or fallback' },
  { key = '[d',            func = require('navigator.diagnostics').goto_prev,                           desc = 'prev diagnostics error or fallback' },
  { key = ']O',            func = vim.diagnostic.set_loclist,                                           desc = 'diagnostics set loclist' },
  { key = ']r',            func = require('navigator.treesitter').goto_next_usage,                      desc = 'goto_next_usage' },
  { key = '[r',            func = require('navigator.treesitter').goto_previous_usage,                  desc = 'goto_previous_usage' },
  { key = '<C-LeftMouse>', func = vim.lsp.buf.definition,                                               desc = 'definition',                        fallback = fallback_fn('<C-LeftMouse>') },
  { key = 'g<LeftMouse>',  func = vim.lsp.buf.implementation,                                           desc = 'implementation' },
  { key = '<Leader>k',     func = require('navigator.dochighlight').hi_symbol,                          desc = 'hi_symbol' },
  { key = '<Space>wa',     func = require('navigator.workspace').add_workspace_folder,                  desc = 'add_workspace_folder' },
  { key = '<Space>wr',     func = require('navigator.workspace').remove_workspace_folder,               desc = 'remove_workspace_folder' },
  { key = '<Space>ff',     func = vim.lsp.buf.format,                                                   desc = 'format',                            mode = { 'n', 'v', 'x' } },
  { key = '<Space>gm',     func = require('navigator.formatting').range_format,                         mode = 'n',                                 desc = 'range format operator e.g gmip' },
  { key = '<Space>wl',     func = require('navigator.workspace').list_workspace_folders,                desc = 'list_workspace_folders' },
  { key = '<Space>la',     func = require('navigator.codelens').run_action,                             desc = 'run code lens action',              mode = 'n' }
  -- stylua: ignore end
}

if _NgConfigValues.lsp.hover then
  table.insert(key_maps, { key = 'K', func = require('navigator.hover').hover, desc = 'hover' })
end

local key_maps_help = {}
-- LuaFormatter on
local M = {}

local ccls_mappings = {
  {
    key = '<Leader>gi',
    func = require('navigator.cclshierarchy').incoming_calls,
    desc = 'incoming_calls',
  },
  {
    key = '<Leader>go',
    func = require('navigator.cclshierarchy').outgoing_calls,
    desc = 'outgoing_calls',
  },
}

local check_cap = function(opts)
  -- log(vim.lsp.get_clients({buffer = 0}))
  local fmt, rfmt, ccls = false, false, false
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
  for _, value in pairs(vim.lsp.get_clients({ buffer = 0 })) do
    trace(value)
    if value ~= nil and value.server_capabilities ~= nil then
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
  local commands = {
    [[command!  -nargs=* Nctags lua require("navigator.ctags").ctags(<f-args>)]],
    "command! -nargs=0 LspLog lua require'navigator.lspclient.config'.open_lsp_log()",
    "command! -nargs=0 LspRestart lua require'navigator.lspclient.config'.reload_lsp()",
    "command! -nargs=0 LspToggleFmt lua require'navigator.lspclient.mapping'.toggle_lspformat()<CR>",
    "command! -nargs=0 LspKeymaps lua require'navigator.lspclient.mapping'.get_keymaps_help()<CR>",
    "command! -nargs=0 LspSymbols lua require'navigator.symbols'.side_panel()<CR>",
    "command! -nargs=0 TSymbols lua require'navigator.treesitter'.side_panel()<CR>",
    "command! -nargs=0 NRefPanel lua require'navigator.reference'.side_panel()<CR>",
    "command! -nargs=* Calltree lua require'navigator.hierarchy'.calltree(<f-args>)<CR>",
    "command! -nargs=* TsAndDiag lua require'navigator.sidepanel'.treesitter_and_diag_panel(<f-args>)<CR>",
    "command! -nargs=* LspAndDiag lua require'navigator.sidepanel'.lsp_and_diag_panel(<f-args>)<CR>",
  }

  for _, value in pairs(commands) do
    vim.cmd(value)
  end
end

-- should works for both 1)attach from known lsp client or from a disabled lsp client
-- executed in on_attach context
local function set_mapping(lsp_attach_info)
  local opts = { noremap = true, silent = true }
  vim.validate({
    lsp_attach_info = { lsp_attach_info, 'table' },
  })
  if _NgConfigValues.debug then
    log('setup mapping for client', lsp_attach_info.client.name, lsp_attach_info.client.cmd)
  end
  local user_key = _NgConfigValues.keymaps or {}
  local bufnr = lsp_attach_info.bufnr or 0

  local ks = {}
  local function del_keymap(mode, key, ...)
    local k = ks[mode]
    if not k then
      ks[mode] = vim.api.nvim_buf_get_keymap(bufnr, mode)
      k = ks[mode]
    end
    if vim.tbl_contains(k, key) then
      vim.api.nvim_buf_del_keymap(bufnr, mode, key)
    end
  end

  local doc_fmt, range_fmt, ccls = check_cap(lsp_attach_info)

  if ccls then
    vim.list_extend(key_maps, ccls_mappings)
  end

  if _NgConfigValues.default_mapping ~= false then
    for _, v in pairs(user_key) do
      trace('binding', v)
      local exists = false
      for _, default in pairs(key_maps) do
        if
        -- override only if func and mode are the same
            v.func == default.func
            and (v.mode or 'n') == (default.mode or 'n')
            and not default.override
        then
          default.key, default.override, exists = v.key, true, true
          break
        end
      end
      if not exists then
        table.insert(key_maps, v)
      end
    end
  else
    -- disable default mapping
    key_maps = _NgConfigValues.keymaps or {}
    log('setting maps to ', key_maps)
  end
  local fmtkey, rfmtkey, nrfmtkey
  for _, value in pairs(key_maps) do
    if value.doc then
      vim.notify('doc field no longer supported in navigator mapping, use desc instead')
    end
    if type(value.func) == 'function' then
      -- neovim 0.7.0
      opts.buffer = key_maps.buffer or value.buffer
      if value.desc then
        opts.desc = value.desc
      end
      opts.buffer = bufnr
      if value.opts then
        for k, v in pairs(value.opts) do
          opts[k] = v
        end
      end
      vim.keymap.set(value.mode or 'n', value.key, value.func, opts)
      if string.find(value.desc, 'range format') and value.mode == 'v' then
        rfmtkey = value.key
        if string.find(value.desc, 'range format') and value.mode == 'n' then
          nrfmtkey = value.key
        elseif string.find(value.desc, 'format') then
          fmtkey = value.key
        end
      end
    end
  end
  for _, val in pairs(key_maps) do
    local helper_msg = ''
    if val.desc then
      helper_msg = val.desc
    elseif type(val.func) == 'string' then
      helper_msg = val.func
    end

    local item = vim.inspect(val.mode or 'n') .. '|' .. val.key .. '|' .. helper_msg
    if not vim.tbl_contains(key_maps_help, item) then
      table.insert(key_maps_help, vim.inspect(val.mode or 'n') .. '|' .. val.key .. '|' .. helper_msg)
    end
  end

  -- if user_opts.cap.document_formatting then

  if doc_fmt and _NgConfigValues.lsp.format_on_save then
    local fos = _NgConfigValues.lsp.format_on_save
    local gn = api.nvim_create_augroup('NavAuGroupFormat', {})

    local fmt = false
    if type(fos) == 'boolean' then
      fmt = fos
    end
    if type(fos) == 'table' and (fos.enable or fos.disable) then
      if fos.enable then
        -- lsp.format_on_save = {enable = {"python"}}
        fmt = vim.tbl_contains(fos.enable, vim.o.ft)
      end
      -- lsp.format_on_save = {disable = {"python"}}
      if fos.disable then
        fmt = not vim.tbl_contains(fos.disable, vim.o.ft)
      end
    end
    if type(fos) == 'function' then
      fmt = fos(bufnr)
    end
    local fopts = _NgConfigValues.lsp.format_options

    if fopts.async == nil and vim.api.nvim_buf_line_count(0) > 4000 then
      fopts.async = true
    end

    if fmt then
      api.nvim_create_autocmd({ 'BufWritePre' }, {
        group = gn,
        desc = 'auto format',
        buffer = bufnr,
        callback = function()
          trace('format' .. vim.inspect(fopts))
          vim.lsp.buf.format(fopts)
        end,
      })
    end
  elseif fmtkey then
    del_keymap('n', fmtkey)
  end

  if lsp_attach_info.cap and lsp_attach_info.cap.document_range_formatting then
    log('formatting enabled', lsp_attach_info.cap)
  end

  if not range_fmt and rfmtkey then
    del_keymap('v', rfmtkey)
  end

  if not range_fmt and nrfmtkey then
    del_keymap('n', nrfmtkey)
  end
  log('enable format ', doc_fmt, range_fmt, _NgConfigValues.lsp.format_on_save)
end

local function autocmd()
  local gn = api.nvim_create_augroup('NavAuGroupDocHlAu', {})

  api.nvim_create_autocmd({ 'BufWritePre' }, {
    group = gn,
    desc = 'doc highlight',
    callback = require('navigator.dochighlight').cmd_nohl,
  })

  api.nvim_create_autocmd({ 'CmdlineLeave' }, {
    group = gn,
    desc = 'doc highlight nohl',
    callback = require('navigator.dochighlight').cmd_nohl,
  })
end

M.toggle_lspformat = function(on)
  if on == nil then
    _NgConfigValues.lsp.format_on_save = not _NgConfigValues.lsp.format_on_save
  else
    _NgConfigValues.lsp.format_on_save = on
  end
  if _NgConfigValues.lsp.format_on_save then
    if on == nil then
      vim.notify('format on save true', vim.log.levels.INFO)
    end
    vim.cmd([[set eventignore-=BufWritePre]])
  else
    if on == nil then
      vim.notify('format on save false', vim.log.levels.INFO)
    end
    vim.cmd([[set eventignore+=BufWritePre]])
  end
end

function M.setup(attach_opts)
  if not attach_opts or not attach_opts.client then
    vim.notify(
      'please call require"navigator.mapping".setup({bufnr=bufnr, client=client}) inside on_attach(client,bufnr)',
      vim.log.levels.WARN
    )
  end

  attach_opts = attach_opts or {}
  -- extend the default mapping
  attach_opts = vim.tbl_deep_extend('force', { bufnr = vim.api.nvim_get_current_buf(), client = {}, cap = {} },
    attach_opts)

  set_mapping(attach_opts)
  set_cmds(attach_opts)

  autocmd()

  local client = attach_opts.client or {}
  local cap = client.server_capabilities
  if cap == nil then
    log('no cap found for client ', client.name)
    return
  end

  log('lsp cap:', cap.codeActionProvider)

  if
      _NgConfigValues.lsp.call_hierarchy.enable and cap.call_hierarchy or cap.callHierarchyProvider
  then
    vim.lsp.handlers['callHierarchy/incomingCalls'] =
        require('navigator.hierarchy').incoming_calls_handler
    vim.lsp.handlers['callHierarchy/outgoingCalls'] =
        require('navigator.hierarchy').outgoing_calls_handler
  end

  if _NgConfigValues.lsp.definition.enable then
    for _, value in pairs(key_maps) do
      if value.func == vim.lsp.buf.definition then
        vim.lsp.handlers['textDocument/definition'] = util.mk_handler_remap(
          require('navigator.definition').definition_handler, value.fallback)
      end

      if value.func == vim.lsp.buf.type_definition then
        vim.lsp.handlers['textDocument/typeDefinition'] = util.mk_handler_remap(
          require('navigator.definition').definition_handler, value.fallback)
      end
    end
  else
    -- delete keymaps
    for _, value in pairs(key_maps) do
      if value.func == vim.lsp.buf.definition or value.func == vim.lsp.buf.type_definition then
        vim.keymap.del(value.mode or 'n', value.key, { buffer = attach_opts.bufnr or vim.api.nvim_get_current_buf() })
      end
    end
  end

  vim.lsp.handlers['textDocument/references'] = require('navigator.reference').reference_handler
  -- vim.lsp.handlers["textDocument/codeAction"] = require"navigator.codeAction".code_action_handler

  if cap.declarationProvider then
    local hdlr = require('navigator.definition').declaration_handler

    for _, value in pairs(key_maps) do
      if value.func == vim.lsp.buf.declaration then
        vim.lsp.handlers['textDocument/declaration'] = util.mk_handler_remap(hdlr, value.fallback)
        break
      end
    end
  else
    -- remove declaration keymap
    for _, value in pairs(key_maps) do
      if value.func == vim.lsp.buf.declaration then
        vim.keymap.del(value.mode or 'n', value.key, { buffer = attach_opts.bufnr or vim.api.nvim_get_current_buf() })
        break
      end
    end
  end

  if _NgConfigValues.lsp.implementation.enable then
    vim.lsp.handlers['textDocument/implementation'] =
        require('navigator.implementation').implementation_handler
  end

  -- vim.lsp.handlers['textDocument/documentSymbol'] = require('navigator.symbols').document_symbol_handler
  if _NgConfigValues.lsp.workspace.enable then
    vim.lsp.handlers['workspace/symbol'] = require('navigator.symbols').workspace_symbol_handler
  end
  if _NgConfigValues.lsp.diagnostic.enable then
    vim.lsp.handlers['textDocument/publishDiagnostics'] =
        require('navigator.diagnostics').diagnostic_handler
  end

  if
      vim.fn.empty(_NgConfigValues.signature_help_cfg) == 0 or _NgConfigValues.lsp_signature_help
  then
    log('setup signature from navigator')
    local hassig, sig = pcall(require, 'lsp_signature')
    if hassig then
      sig.setup(_NgConfigValues.signature_help_cfg or {})
    end
  end

  api.nvim_create_autocmd({ 'BufWritePre' }, {
    group = api.nvim_create_augroup('nvim_nv_event_autos', {}),
    buffer = attach_opts.bufnr,
    desc = 'diagnostic update',
    callback = function()
      require('navigator.diagnostics').setloclist(attach_opts.bufnr)
    end,
  })

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
    rect = { height = 24, width = 50 },
    data = key_maps_help,
  })

  return win
end

return M
