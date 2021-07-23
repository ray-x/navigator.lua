local log = require"navigator.util".log
local function set_keymap(...)
  vim.api.nvim_set_keymap(...)
end

local event_hdlrs = {
  {ev = "BufWritePre", func = "diagnostic.set_loclist({open_loclist = false})"},
  {ev = "CursorHold", func = "document_highlight()"},
  {ev = "CursorHoldI", func = "document_highlight()"},
  {ev = "CursorMoved", func = "clear_references()"}
}

local double = {"╔", "═", "╗", "║", "╝", "═", "╚", "║"}
local single = {"╭", "─", "╮", "│", "╯", "─", "╰", "│"}
-- LuaFormatter off
local key_maps = {
  {key = "gr", func = "references()"},
  {mode = "i", key = "<M-k>", func = "signature_help()"},
  {key = "gs", func = "signature_help()"},
  {key = "g0", func = "document_symbol()"},
  {key = "gW", func = "workspace_symbol()"},
  {key = "<c-]>", func = "definition()"},
  {key = "gD", func = "declaration({ popup_opts = { border = 'single' }})"},
  {key = "gp", func = "require('navigator.definition').definition_preview()"},
  {key = "gT", func = "require('navigator.treesitter').buf_ts()"},
  {key = "GT", func = "require('navigator.treesitter').bufs_ts()"},
  {key = "K", func = "hover({ popup_opts = { border = single }})"},
  {key = "<Space>ca", mode = "n", func = "code_action()"},
  {key = "<Space>cA", mode = "v", func = "range_code_action()"},
  {key = "<Leader>re", func = "rename()"},
  {key = "<Space>rn", func = "require('navigator.rename').rename()"},
  {key = "<Leader>gi", func = "incoming_calls()"},
  {key = "<Leader>go", func = "outgoing_calls()"},
  {key = "gi", func = "implementation()"},
  {key = "<Space>D", func = "type_definition()"},
  {key = "gL", func = "diagnostic.show_line_diagnostics({ popup_opts = { border = single }})"},
  {key = "gG", func = "require('navigator.diagnostics').show_diagnostic()"},
  {key = "]d", func = "diagnostic.goto_next({ popup_opts = { border = single }})"},
  {key = "[d", func = "diagnostic.goto_next({ popup_opts = { border = single }})"},
  {key = "]r", func = "require('navigator.treesitter').goto_next_usage()"},
  {key = "[r", func = "require('navigator.treesitter').goto_previous_usage()"},
  {key = "<C-LeftMouse>", func = "definition()"},
  {key = "g<LeftMouse>", func = "implementation()"},
  {key = "<Leader>k", func = "require('navigator.dochighlight').hi_symbol()"},
  {key = '<Space>wa', func = '<cmd>lua vim.lsp.buf.add_workspace_folder()'},
  {key = '<Space>wr', func = '<cmd>lua vim.lsp.buf.remove_workspace_folder()'},
  {key = '<Space>wl', func = '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))'},
}
-- LuaFormatter on
local M = {}

local ccls_mappings = {
  {key = "<Leader>gi", func = "require('navigator.cclshierarchy').incoming_calls()"},
  {key = "<Leader>go", func = "require('navigator.cclshierarchy').outgoing_calls()"}
}

local function set_mapping(user_opts)
  local opts = {noremap = true, silent = true}
  user_opts = user_opts or {}

  local user_key = user_opts.keymaps or {}
  local bufnr = user_opts.bufnr or 0

  local function buf_set_keymap(...)
    vim.api.nvim_buf_set_keymap(bufnr, ...)
  end

  -- local function buf_set_option(...)
  --   vim.api.nvim_buf_set_option(bufnr, ...)
  -- end
  for _, v in pairs(user_key) do
    local exists = false
    for _, default in pairs(key_maps) do
      if v.func == default.func and (not default.override) then
        default.key, default.override, exists = v.key, true, true
        break
      end
    end
    if not exists then
      table.insert(key_maps, v)
    end
  end
  -- log(key_maps)

  -- local key_opts = {vim.tbl_deep_extend("force", key_maps, unpack(result))}
  for _, value in pairs(key_maps) do
    local f = "<Cmd>lua vim.lsp.buf." .. value.func .. "<CR>"
    if string.find(value.func, "require") then
      f = "<Cmd>lua " .. value.func .. "<CR>"
    elseif string.find(value.func, "diagnostic") then
      f = "<Cmd>lua vim.lsp." .. value.func .. "<CR>"
    end
    local k = value.key
    local m = value.mode or "n"
    set_keymap(m, k, f, opts)
  end

  -- format setup

  local range_fmt = false
  local doc_fmt = false
  local ccls = false
  -- log(vim.lsp.buf_get_clients(0))
  for _, value in pairs(vim.lsp.buf_get_clients(0)) do
    if value == nil or value.resolved_capabilities == nil then
      return
    end
    if value.resolved_capabilities.document_formatting then
      doc_fmt = true
    end
    if value.resolved_capabilities.document_range_formatting then
      range_fmt = true
    end

    -- log("override ccls", value.config)
    if value.config.name == "ccls" then

      ccls = true
    end
  end

  if ccls then
    -- log("override ccls", ccls_mappings)
    for _, value in pairs(ccls_mappings) do
      f = "<Cmd>lua " .. value.func .. "<CR>"
      local k = value.key
      local m = value.mode or "n"
      set_keymap(m, k, f, opts)
    end
  end
  -- if user_opts.cap.document_formatting then
  if doc_fmt then
    buf_set_keymap("n", "<space>ff", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
    vim.cmd([[
      aug NavigatorAuFormat
        au!
        autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting()
      aug END
     ]])
  end
  -- if user_opts.cap.document_range_formatting then
  if range_fmt then
    buf_set_keymap("v", "<space>ff", "<cmd>lua vim.lsp.buf.range_formatting()<CR>", opts)
  end
  log("enable format ", doc_fmt, range_fmt)
end

local function autocmd(user_opts)
  vim.api.nvim_exec([[
            aug NavigatorDocHlAu
                au!
                au CmdlineLeave : lua require('navigator.dochighlight').cmd_nohl()
            aug END
        ]], false)
end

local function set_event_handler(user_opts)
  user_opts = user_opts or {}
  local file_types =
      "c,cpp,h,go,python,vim,sh,javascript,html,css,lua,typescript,rust,javascriptreact,typescriptreact,json,yaml,kotlin,php,dart,nim,terraform"
  -- local format_files = "c,cpp,h,go,python,vim,javascript,typescript" --html,css,
  vim.api.nvim_command [[augroup nvim_lsp_autos]]
  vim.api.nvim_command [[autocmd!]]

  for _, value in pairs(event_hdlrs) do
    local f = ""
    if string.find(value.func, "diagnostic") then
      f = "lua vim.lsp." .. value.func
    else
      f = "lua vim.lsp.buf." .. value.func
    end
    local cmd = "autocmd FileType " .. file_types .. " autocmd nvim_lsp_autos " .. value.ev
                    .. " <buffer> silent! " .. f
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
      print("format on save true")
    end
    vim.cmd([[set eventignore=""]])
  else
    if on == nil then
      print("format on save false")
    end
    vim.cmd([[set eventignore=BufWritePre]])
  end

end

function M.setup(user_opts)
  user_opts = user_opts or _NgConfigValues
  if _NgConfigValues.default_mapping == true then
    set_mapping(user_opts)
  end

  autocmd(user_opts)
  set_event_handler(user_opts)

  local cap = user_opts.cap or vim.lsp.protocol.make_client_capabilities()
  if cap.call_hierarchy or cap.callHierarchy then
    vim.lsp.handlers["callHierarchy/incomingCalls"] =
        require"navigator.hierarchy".incoming_calls_handler
    vim.lsp.handlers["callHierarchy/outgoingCalls"] =
        require"navigator.hierarchy".outgoing_calls_handler
  end

  vim.lsp.handlers["textDocument/references"] = require"navigator.reference".reference_handler
  vim.lsp.handlers["textDocument/codeAction"] = require"navigator.codeAction".code_action_handler
  vim.lsp.handlers["textDocument/definition"] = require"navigator.definition".definition_handler

  if cap.declaration then
    vim.lsp.handlers["textDocument/declaration"] = require"navigator.definition".declaration_handler
  end

  vim.lsp.handlers["textDocument/typeDefinition"] =
      require"navigator.definition".typeDefinition_handler
  vim.lsp.handlers["textDocument/implementation"] =
      require"navigator.implementation".implementation_handler

  vim.lsp.handlers["textDocument/documentSymbol"] =
      require"navigator.symbols".document_symbol_handler
  vim.lsp.handlers["workspace/symbol"] = require"navigator.symbols".workspace_symbol_handler
  vim.lsp.handlers["textDocument/publishDiagnostics"] =
      require"navigator.diagnostics".diagnostic_handler

  -- TODO: when active signature merge to neovim, remove this setup:
  local hassig, sig = pcall(require, "lsp_signature")
  if not hassig then
    vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
                                                         require"navigator.signature".signature_handler,
                                                         {
          border = {"╭", "─", "╮", "│", "╯", "─", "╰", "│"}
        })
  end

  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {border = single})
  vim.lsp.handlers["textDocument/formatting"] = require"navigator.formatting".format_hdl
end

return M
