-- todo allow config passed in
local ng_util = require('navigator.util')
local log = ng_util.log
local trace = ng_util.trace
local empty = ng_util.empty
local warn = ng_util.warn
local vfn = vim.fn
_NG_Loaded = {}

_LoadedFiletypes = {}

-- packer only

local highlight = require('navigator.lspclient.highlight')

local has_lsp, lspconfig = pcall(require, 'lspconfig')
local has_nvim_011 = vfn.has('nvim-0.11')
if not has_lsp and not has_nvim_011 then
  vim.notify('loading lsp config failed LSP may not working correctly', vim.log.levels.WARN)
end

local config = require('navigator').config_values()
local disabled_ft = {
  'NvimTree',
  'guihua',
  'clap_input',
  'clap_spinner',
  'vista',
  'vista_kind',
  'TelescopePrompt',
  'guihua_rust',
  'csv',
  'txt',
  'defx',
  'packer',
  'gitcommit',
  'neo-tree',
  'windline',
  'notify',
  'nofile',
  'help',
  'dap-*',
  'dapui_*',
  '',
}
-- local cap = vim.lsp.protocol.make_client_capabilities()
-- gopls["ui.completion.usePlaceholders"] = true


local servers = require('navigator.lspclient.servers')

local ng_default_cfg = {
  flags = { allow_incremental_sync = true, debounce_text_changes = 1000 },
}

-- check and load based on file type
local function load_cfg(ft, client, cfg, loaded, starting)
  log(ft, client, loaded, starting)
  trace(cfg)
  if lspconfig[client] == nil then
    log('not supported by nvim', client)
    return
  end

  local lspft = lspconfig[client].document_config.default_config.filetypes
  local additional_ft = lspconfig[client] and lspconfig[client].filetypes or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local cmd = cfg.cmd
  trace(lspft, additional_ft, _NG_Loaded)
  _NG_Loaded[bufnr] = _NG_Loaded[bufnr] or { cnt = 0, lsp = {} }
  local should_load = false
  if lspft ~= nil and #lspft > 0 then
    for _, value in ipairs(lspft) do
      if ft == value then
        should_load = true
      end
    end
    if should_load == false then
      return
    end

    trace('lsp for client', client, cfg)
    if cmd == nil or #cmd == 0 or vfn.executable(cmd[1]) == 0 then
      log('lsp not installed for client', client, cmd, "fallback")
      return
    end

    for k, c in pairs(loaded) do
      if client == k then
        -- loaded
        log(client, 'already been loaded for', ft, loaded, c)
        if _NG_Loaded[bufnr].cnt < 4 then
          log('doautocmd filetype')
          vim.defer_fn(function()
            vim.cmd('doautocmd FileType')
            _NG_Loaded[bufnr].cnt = _NG_Loaded[bufnr].cnt + 1
          end, 100)
          return
        end
      end
    end

    local clients = vim.lsp.get_clients({ buffer = 0 })
    for _, c in pairs(clients or {}) do
      log("lsp start up in progress client", client, c.name)
      if c.name == client then
        _NG_Loaded[bufnr].cnt = 10
        table.insert(_NG_Loaded[bufnr].lsp, c.name)
        _NG_Loaded[client] = true
        return
      end
    end

    if starting and (starting.cnt or 0) > 0 then
      log("lsp start up in progress", starting)
      return vim.defer_fn(function()
          load_cfg(ft, client, cfg, loaded, { cnt = starting.cnt - 1 })
        end,
        100)
    end

    if lspconfig[client] == nil then
      error('client ' .. client .. ' not supported')
      return
    end

    trace('load cfg', cfg)
    log('lspconfig setup')
    -- log(lspconfig.available_servers())
    -- force reload with config
    -- lets have a guard here
    trace(_NG_Loaded[bufnr])
    if not _NG_Loaded[client] then
      trace(client, 'loading for', ft, cfg)
      trace(lspconfig[client])
      -- lspconfig[client].setup(cfg)
      vim.lsp.enable(client)
      _NG_Loaded[client] = true
      table.insert(_NG_Loaded[bufnr].lsp, client)
      vim.defer_fn(function()
        log('send filetype event')
        vim.cmd([[doautocmd Filetype]])
        _NG_Loaded[bufnr].cnt = _NG_Loaded[bufnr].cnt + 1
      end, 400)
    else
      log('send filetype event')
      if not _NG_Loaded[bufnr] or _NG_Loaded[bufnr].cnt < 4 then
        log('doautocmd filetype')
        vim.defer_fn(function()
          vim.cmd('doautocmd FileType')
          _NG_Loaded[bufnr].cnt = _NG_Loaded[bufnr].cnt + 1
        end, 100)
      end
    end
  end
  -- need to verify the lsp server is up
end

local function setup_fmt(client, enabled)
  if enabled == false then
    client.server_capabilities.documentFormattingProvider = false
  else
    client.server_capabilities.documentFormattingProvider = client.server_capabilities.documentFormattingProvider
        or enabled
  end
end

local function update_capabilities()
  trace(vim.o.ft, 'lsp startup')
  local capabilities = vim.lsp.protocol.make_client_capabilities()

  local installed, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
  if installed and cmp_lsp then
    capabilities = cmp_lsp.default_capabilities()
  else
    capabilities.textDocument.completion = {
      completionItem = {
        snippetSupport = vim.snippet and true or false,
        resolveSupport = {
          properties = { 'edit', 'documentation', 'detail', 'additionalTextEdits' },
        },
      },
      completionList = {
        itemDefaults = {
          'editRange',
          'insertTextFormat',
          'insertTextMode',
          'data',
        },
      },
    }
  end
  return capabilities
end

-- run setup for lsp clients

local loaded = {}
local function lsp_startup(ft, retry, user_lsp_opts)
  retry = retry or false
  local path_sep = require('navigator.util').path_sep()
  local capabilities = update_capabilities()

  for _, lspclient in ipairs(servers) do
    local clients = vim.lsp.get_clients() or {}
    for _, client in ipairs(clients) do
      if client ~= nil then
        loaded[client.name] = client.id
      end
    end
    -- check should load lsp

    if type(lspclient) == 'table' then
      if lspclient.name then
        lspclient = lspclient.name
      else
        warn('incorrect set for lspclient' .. vim.inspect(lspclient))
        goto continue
      end
    end

    -- for lazy loading
    -- e.g. {lsp={tsserver=function() if tsver>'1.17' then return {xxx} else return {xxx} end}}
    if type(user_lsp_opts[lspclient]) == 'function' then
      user_lsp_opts[lspclient] = user_lsp_opts[lspclient]()
      trace('loading from func:', user_lsp_opts[lspclient])
    elseif user_lsp_opts[lspclient] ~= nil and user_lsp_opts[lspclient].filetypes ~= nil then
      if not vim.tbl_contains(user_lsp_opts[lspclient].filetypes, ft) then
        trace('ft', ft, 'disabled for', lspclient)
        goto continue
      end
    end

    if vim.tbl_contains(config.lsp.disable_lsp or {}, lspclient) then
      log('disable lsp', lspclient)
      goto continue
    end

    local default_config = {}
    if lspconfig[lspclient] == nil then
      vim.schedule(function()
        vim.notify(
          'lspclient' .. vim.inspect(lspclient) .. 'no longer support by lspconfig, please submit an issue',
          vim.log.levels.WARN
        )
      end)
      log('lspclient', lspclient, 'not supported')
      goto continue
    end

    if lspconfig[lspclient].document_config and lspconfig[lspclient].document_config.default_config then
      default_config = lspconfig[lspclient].document_config.default_config
    else
      vim.schedule(function()
        vim.notify('missing document config for client: ' .. vim.inspect(lspclient), vim.log.levels.WARN)
      end)
      goto continue
    end

    default_config = vim.tbl_deep_extend('force', default_config, ng_default_cfg)
    local cfg = vim.lsp.config[lspclient] or require('lspconfig')[lspclient] or {}

    cfg = vim.tbl_deep_extend('keep', cfg, default_config)
    -- filetype disabled
    if not vim.tbl_contains(cfg.filetypes or {}, ft) then
      trace('ft', ft, 'disabled for', lspclient)

      goto continue
    end

    local disable_fmt = false

    log(lspclient)
    -- if user provides override values
    cfg.capabilities = capabilities
    log(lspclient, config.lsp.disable_format_cap)
    if vim.tbl_contains(config.lsp.disable_format_cap or {}, lspclient) then
      log('fileformat disabled for ', lspclient)
      disable_fmt = true
    end

    local enable_fmt = not disable_fmt
    if user_lsp_opts[lspclient] ~= nil then
      -- log(lsp_opts[lspclient], cfg)
      cfg = vim.tbl_deep_extend('force', cfg, user_lsp_opts[lspclient])
      -- if config.combined_attach == nil then
      --   setup_fmt(client, enable_fmt)
      -- end
      cfg.on_init = function(client)
        if client and client.config and client.config.settings then
          client.notify(
            'workspace/didChangeConfiguration',
            { settings = client.config.settings },
            vim.log.levels.WARN
          )
        end
      end
    else
      cfg.on_attach = function(client, bufnr)
        setup_fmt(client, enable_fmt)
      end
    end

    log('loading', lspclient, 'name', lspconfig[lspclient].name)
    -- start up lsp

    if vfn.executable(cfg.cmd[1]) == 0 then
      log('lsp server not installed in path ' .. lspclient .. vim.inspect(cfg.cmd), vim.log.levels.WARN)
    end

    if _NG_Loaded[lspclient] then
      log('client loaded ?', lspclient, _NG_Loaded[lspclient])
    end
    local starting = {}
    if _NG_Loaded[lspclient] == true then
      starting = { cnt = 1 }
    end

    load_cfg(ft, lspclient, cfg, loaded, starting)
    -- load_cfg(ft, lspclient, {}, loaded)
    ::continue::
  end

  if not _NG_Loaded['null_ls'] then
    local nulls_cfg = user_lsp_opts['null_ls']
    if nulls_cfg then
      local cfg = {}
      cfg = vim.tbl_deep_extend('keep', cfg, nulls_cfg)
      vim.lsp.config['null-ls'] = cfg
      vim.lsp.enable('null-ls')
    end
  end

  if not retry or ft == nil then
    return
  end
end

-- append lsps to servers
local function add_servers(lsps)
  vim.validate({ lsps = { lsps, 't' } })
  vim.list_extend(servers, lsps)
end

local function get_cfg(client)
  local ng_cfg = ng_default_cfg
  if setups[client] ~= nil then
    local ng_setup = vim.deepcopy(setups[client])
    ng_setup.cmd = nil
    return ng_setup
  else
    return ng_cfg
  end
end

local function ft_disabled(ft)
  for i = 1, #disabled_ft do
    if ft == disabled_ft[i] then
      return true
    end
    if disabled_ft[i]:find('*') then
      local pattern = disabled_ft[i]:gsub('*', '')
      if ft:find(pattern) then
        return true
      end
    end
  end
end
local ft_map = {
  js = 'javascript',
  ts = 'typescript',
  jsx = 'javascriptreact',
  tsx = 'typescriptreact',
  mod = 'gomod',
  cxx = 'cpp',
  chh = 'cpp',
  hs = 'haskell',
  pl = 'perl',
  rs = 'rust',
  rb = 'ruby',
  py = 'python',
}

local function setup(user_opts)
  if config.lsp.disable_lsp == 'all' then
    config.lsp.disable_lsp = servers
  end

  user_opts = user_opts or {}
  local bufnr = user_opts.bufnr or vim.api.nvim_get_current_buf()

  local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  if vim.fn.empty(ft) == 1 then
    local ext = vfn.expand('%:e')
    local lang = ft_map[ext] or ext or ''
    log('nil filetype, callback', vim.fn.expand('%'), vim.fn.expand('%'), lang)
    if vim.fn.empty(lang) == 0 then
      log('set filetype', ft, ext)

      vim.api.nvim_set_option_value('filetype', lang, { buf = bufnr })
      vim.api.nvim_set_option_value('syntax', 'on', { buf = bufnr })
      ft = vim.api.nvim_get_option_value('ft', { buf = bufnr })
      if vim.fn.empty(ft) == 1 then
        log('still failed to idnetify filetype, try again')
        vim.cmd(':e')
      end
    end
    log('no filetype, no ext return')


    ft = vim.api.nvim_get_option_value('ft', { buf = bufnr })
    log('get filetype', ft)
  end
  local uri = vim.uri_from_bufnr(bufnr)

  if uri == 'file://' or uri == 'file:///' then
    log('skip loading for ft ', ft, uri)
    return
  end
  if _LoadedFiletypes[ft .. tostring(bufnr)] == true then
    log('navigator was loaded for ft', ft, bufnr)
    return
  end

  if ft_disabled(ft) then
    trace('navigator disabled for ft or it is loaded', ft)
    return
  end

  if _NgConfigValues.lsp.servers then
    add_servers(_NgConfigValues.lsp.servers)
    _NgConfigValues.lsp.servers = nil
  end

  trace(debug.traceback())

  local clients = vim.lsp.get_clients({ buffer = bufnr })
  for key, client in pairs(clients) do
    if client.name ~= 'null_ls' and client.name ~= 'efm' then
      if vim.tbl_contains(client.filetypes or {}, vim.bo.ft) then
        log('client already loaded', client.name)
      end
    end
  end

  user_opts = vim.tbl_extend('keep', user_opts, config) -- incase setup was triggered from autocmd

  log('running lsp setup', ft, bufnr)
  local retry = true

  log('loading for ft ', ft, uri)
  highlight.config_signs()
  highlight.add_highlight()
  local lsp_opts = user_opts.lsp or {}

  lsp_startup(ft, retry, lsp_opts)
end

local function on_filetype()
  local bufnr = vim.api.nvim_get_current_buf()
  local uri = vim.uri_from_bufnr(bufnr)

  local ft = vim.bo.filetype
  if ft == nil then
    return
  end
  if uri == 'file://' or uri == 'file:///' or vim.wo.diff then
    trace('skip loading for ft ', ft, uri)
    return
  end
  _NG_Loaded[bufnr] = _NG_Loaded[bufnr] or { cnt = 1, lsp = {} }

  trace(_NG_Loaded)
  local loaded
  if _NG_Loaded[bufnr].cnt > 1 then
    log('navigator was loaded for ft', ft, bufnr)
    -- check if lsp is loaded
    local clients = vim.lsp.get_clients({ buffer = bufnr })
    for key, client in pairs(clients) do
      if client.name ~= 'null_ls' and client.name ~= 'efm' then
        loaded = _NG_Loaded[bufnr].lsp[client.name]
      end
    end
    if not loaded then
      -- trigger filetype so that lsp can be loaded
      -- fire the check in 200 ms
      vim.cmd('setlocal filetype=' .. ft)
    end
    return
  end

  -- on_filetype should only be trigger only once for each bufnr
  _NG_Loaded[bufnr].cnt = _NG_Loaded[bufnr].cnt + 1 -- do not hook and trigger filetype event multiple times
  -- as setup will send  filetype event as well
  log(uri)

  local wids = vfn.win_findbuf(bufnr)
  if empty(wids) then
    log('buf not shown return')
  end
  setup({ bufnr = bufnr })
end

return {
  setup = setup,
  get_cfg = get_cfg,
  add_servers = add_servers,
  on_filetype = on_filetype,
  disabled_ft = disabled_ft,
  ft_disabled = ft_disabled,
}
