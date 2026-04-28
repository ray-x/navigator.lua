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

local has_nvim_012 = vfn.has('nvim-0.12')
if not has_nvim_012 then
  vim.notify('navigator.lua requires nvim 0.12+, please update neovim', vim.log.levels.WARN)
end

local lspconfig = vim.lsp.config
if not lspconfig then
  vim.notify('invalid nvim version pls use nvim 0.12+', vim.log.levels.INFO)
  return {}
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
  flags = { debounce_text_changes = 500 },
}

local function resolve_root_dir(bufnr, cfg)
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  if type(cfg.root_dir) == 'function' and bufname ~= '' then
    local ok, root_dir = pcall(cfg.root_dir, bufname)
    if ok and type(root_dir) == 'string' and root_dir ~= '' then
      return root_dir
    end
  elseif type(cfg.root_dir) == 'string' and cfg.root_dir ~= '' then
    return cfg.root_dir
  end

  if type(cfg.root_markers) == 'table' and #cfg.root_markers > 0 then
    local ok, root_dir = pcall(vim.fs.root, bufnr, cfg.root_markers)
    if ok and type(root_dir) == 'string' and root_dir ~= '' then
      return root_dir
    end
  end
end

-- check and load based on file type
local function load_cfg(ft, client, cfg)
  log(ft, client)
  trace(cfg)
  if lspconfig[client] == nil or lspconfig[client].filetypes == nil then
    log('not supported by nvim', client)
    error('client ' .. client .. ' not supported or invalid neovim version')
    return
  end

  local lspft = lspconfig[client].filetypes
  local additional_ft = lspconfig[client] and lspconfig[client].filetypes or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local cmd = cfg.cmd
  local root_dir = resolve_root_dir(bufnr, cfg)
  local needs_root = type(cfg.root_dir) == 'function'
    or (type(cfg.root_markers) == 'table' and #cfg.root_markers > 0)
  trace(lspft, additional_ft, _NG_Loaded)
  _NG_Loaded[bufnr] = _NG_Loaded[bufnr] or { lsp = {} }
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

    if needs_root and (type(root_dir) ~= 'string' or root_dir == '') then
      trace('skip loading for client without project root', client, ft, cfg.root_markers)
      return
    end

    if type(root_dir) == 'string' and root_dir ~= '' then
      cfg.root_dir = root_dir
    end

    trace('lsp for client', client, cfg)
    if type(cmd) == 'string' and vfn.executable(cmd) == 0 then
      log('lsp not installed for client', client, cmd, 'fallback')
      return
    end

    if type(cmd) == 'table' and (#cmd == 0 or vfn.executable(cmd[1]) == 0) then
      log('lsp not installed for client', client, cmd, "fallback")
      return
    end

    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    for _, c in pairs(clients or {}) do
      log("lsp start up in progress client", client, c.name)
      if c.name == client then
        _NG_Loaded[bufnr].lsp[c.name] = true
        _NG_Loaded[client] = true
        return
      end
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
      vim.lsp.config[client] = vim.tbl_deep_extend('force', vim.lsp.config[client] or {}, cfg)
      vim.lsp.enable(client)
      _NG_Loaded[client] = true
      _NG_Loaded[bufnr].lsp[client] = true
    else
      _NG_Loaded[bufnr].lsp[client] = true
    end
  end
  -- need to verify the lsp server is up
end

local function setup_fmt(client, enabled)
  if enabled == false then
    client.server_capabilities.documentFormattingProvider = false
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
local function lsp_startup(ft, user_lsp_opts)
  local capabilities = update_capabilities()

  for _, lspclient in ipairs(servers) do
    -- check should load lsp
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

    local lsp_config = vim.lsp.config
    local client_cfg = lsp_config[lspclient] or {}
    -- get config from lsp/lsp_name.lua
    local lsp_dot_cfg = {}
    local require_path = 'lsp.' .. lspclient
    local has_cfg = false
    has_cfg, lsp_dot_cfg = pcall(require, require_path)
    if has_cfg then
      client_cfg = vim.tbl_deep_extend('force', client_cfg, lsp_dot_cfg)
    end

    if client_cfg == nil then
      vim.schedule(function()
        vim.notify(
          'lspclient: ' .. vim.inspect(lspclient) .. 'no longer support by lspconfig, please submit an issue',
          vim.log.levels.WARN
        )
      end)
      log('lspclient', lspclient, 'not supported')
      goto continue
    end

    local default_config = lsp_config[lspclient] or {}

    default_config = vim.tbl_deep_extend('force', default_config, ng_default_cfg)

    local cfg = vim.tbl_deep_extend('keep', client_cfg, default_config)
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
          client:notify(
            'workspace/didChangeConfiguration',
            { settings = client.config.settings }
          )
        end
      end
    else
      cfg.on_attach = function(client, bufnr)
        setup_fmt(client, enable_fmt)
      end
    end

    log('loading', lspclient, 'name', lsp_config[lspclient].name)
    -- start up lsp

    if type(cfg.cmd) == 'string' and vfn.executable(cfg.cmd) == 0 then
      log('lsp server not installed in path ' .. lspclient .. vim.inspect(cfg.cmd), vim.log.levels.WARN)
    elseif type(cfg.cmd) == 'table' and vfn.executable(cfg.cmd[1]) == 0 then
      log('lsp server not installed in path ' .. lspclient .. vim.inspect(cfg.cmd), vim.log.levels.WARN)
    end

    if _NG_Loaded[lspclient] then
      log('client loaded ?', lspclient, _NG_Loaded[lspclient])
    end

    load_cfg(ft, lspclient, cfg)
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

  return
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

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for key, client in pairs(clients) do
    if client.name ~= 'null_ls' and client.name ~= 'efm' then
      if vim.tbl_contains(client.filetypes or {}, vim.bo.ft) then
        log('client already loaded', client.name)
      end
    end
  end

  user_opts = vim.tbl_extend('keep', user_opts, config) -- incase setup was triggered from autocmd

  log('running lsp setup', ft, bufnr)

  log('loading for ft ', ft, uri)
  highlight.config_signs()
  highlight.add_highlight()
  local lsp_opts = user_opts.lsp or {}

  lsp_startup(ft, lsp_opts)
  _LoadedFiletypes[ft .. tostring(bufnr)] = true
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

  if _LoadedFiletypes[ft .. tostring(bufnr)] == true then
    log('navigator was loaded for ft', ft, bufnr)
    return
  end
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
