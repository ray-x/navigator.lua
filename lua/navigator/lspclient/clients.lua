-- todo allow config passed in
local ng_util = require('navigator.util')
local log = ng_util.log
local trace = ng_util.trace
local empty = ng_util.empty
local warn = ng_util.warn
local vfn = vim.fn
_NG_Loaded = {}

_LoadedFiletypes = {}
packer_plugins = packer_plugins or nil -- suppress warnings

-- packer only

local highlight = require('navigator.lspclient.highlight')

local has_lsp, lspconfig = pcall(require, 'lspconfig')
if not has_lsp then
  return {
    setup = function()
      vim.notify('loading lsp config failed LSP may not working correctly', vim.lsp.log_levels.WARN)
    end,
  }
end

local util = lspconfig.util
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
  'windline',
  'notify',
  'nofile',
  'help',
  '',
}
-- local cap = vim.lsp.protocol.make_client_capabilities()
local on_attach = require('navigator.lspclient.attach').on_attach
-- gopls["ui.completion.usePlaceholders"] = true

-- lua setup
local library = {}

local luadevcfg = {
  library = {
    vimruntime = true, -- runtime path
    types = true, -- full signature, docs and completion of vim.api, vim.treesitter, vim.lsp and others
    plugins = { 'nvim-treesitter', 'plenary.nvim' },
  },
  lspconfig = {
    -- cmd = {sumneko_binary},
    on_attach = on_attach,
  },
}

local luadev = {}
local user_luadev = _NgConfigValues.lsp['lua-dev']
if user_luadev then
  luadev = vim.tbl_deep_extend('force', luadev, user_luadev)
end
require('navigator.lazyloader').load('lua-dev.nvim', 'folke/lua-dev.nvim')
if _NgConfigValues.lsp_installer then
  require('navigator.lazyloader').load('nvim-lsp-installer', 'williamboman/nvim-lsp-installer')
end


if _NgConfigValues.mason then
  require('navigator.lazyloader').load('mason.nvim', 'williamboman/mason.nvim')
  require('navigator.lazyloader').load('mason-lspconfig.nvim', 'williamboman/mason-lspconfig.nvim')
end

local setups = require('navigator.lspclient.clients_default').defaults()
local servers =  require('navigator.lspclient.servers')

local lsp_installer_servers = {}
local has_lspinst = false
local has_mason = false

has_lspinst, _ = pcall(require, 'nvim-lsp-installer')
if has_lspinst then
  local srvs = require('nvim-lsp-installer.servers').get_installed_servers()
  if #srvs > 0 then
    lsp_installer_servers = srvs
  end
end

has_mason, _ = pcall(require, 'mason-lspconfig')
if has_mason then
  local srvs=require'mason-lspconfig'.get_installed_servers()
  if #srvs > 0 then
    lsp_installer_servers = srvs
  end
end
log("lsp_installer:", lsp_installer_servers)

if config.lsp.disable_lsp == 'all' then
  config.lsp.disable_lsp = servers
end

local ng_default_cfg = {
  on_attach = on_attach,
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
  local additional_ft = setups[client] and setups[client].filetypes or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local cmd = cfg.cmd
  vim.list_extend(lspft, additional_ft)

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
      log('lsp not installed for client', client, cmd)
      return
    end
    if _NG_Loaded == nil then
      return log('_NG_Loaded not set')
    end

    for k, c in pairs(loaded) do
      if client == k then
        -- loaded
        log(client, 'already been loaded for', ft, loaded, c)
        if not _NG_Loaded[bufnr] or _NG_Loaded[bufnr] < 4 then
          log('doautocmd filetype')
          vim.defer_fn(function()
            vim.cmd('doautocmd FileType')
            _NG_Loaded[bufnr] = (_NG_Loaded[bufnr] or 0 ) + 1
          end, 100)
          return
        end
      end
    end

    local clients = vim.lsp.buf_get_clients(0)
    for _, c in pairs(clients or {}) do
      log("lsp start up in progress client", client, c.name)
      if c.name == client then
        _NG_Loaded[bufnr] = 100
        return
      end
    end

    if starting and (starting.cnt or 0) > 0 then
      log("lsp start up in progress", starting)
      return vim.defer_fn(function()
        load_cfg(ft, client, cfg, loaded, { cnt = starting.cnt - 1 })
      end,
        200)
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
    if not _NG_Loaded[client] then
      log(client, 'loading for', ft, cfg)
      log(lspconfig[client])
      lspconfig[client].setup(cfg)
      _NG_Loaded[client] = true
      vim.defer_fn(function()
        log('send filetype event')
        vim.cmd([[doautocmd Filetype]])
        _NG_Loaded[bufnr] = (_NG_Loaded[bufnr] or 0 )+ 1
      end, 400)
    else
      log('send filetype event')
      if not _NG_Loaded[bufnr] or _NG_Loaded[bufnr] < 4 then
          log('doautocmd filetype')
          vim.defer_fn(function()
            vim.cmd('doautocmd FileType')
            _NG_Loaded[bufnr] = (_NG_Loaded[bufnr] or 0 ) + 1
          end, 100)
      end
    end
  end
  -- need to verify the lsp server is up
end

local function setup_fmt(client, enabled)
  if not require('navigator.util').nvim_0_8() then
    if enabled == false then
      client.resolved_capabilities.document_formatting = enabled
    else
      client.resolved_capabilities.document_formatting = client.resolved_capabilities.document_formatting or enabled
    end
  end

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
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.preselectSupport = true
  capabilities.textDocument.completion.completionItem.insertReplaceSupport = true
  capabilities.textDocument.completion.completionItem.labelDetailsSupport = true
  capabilities.textDocument.completion.completionItem.deprecatedSupport = true
  capabilities.textDocument.completion.completionItem.commitCharactersSupport = true
  capabilities.textDocument.completion.completionItem.tagSupport = { valueSet = { 1 } }
  capabilities.textDocument.completion.completionItem.resolveSupport = {
    properties = { 'documentation', 'detail', 'additionalTextEdits' },
  }
  capabilities.workspace.configuration = true
  return capabilities
end

-- run setup for lsp clients

local loaded = {}
local function lsp_startup(ft, retry, user_lsp_opts)
  retry = retry or false
  local path_sep = require('navigator.util').path_sep()
  local capabilities = update_capabilities()

  for _, lspclient in ipairs(servers) do
    local clients = vim.lsp.get_active_clients() or {}
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
      vim.notify(
        'lspclient' .. vim.inspect(lspclient) .. 'no longer support by lspconfig, please submit an issue',
        vim.lsp.log_levels.WARN
      )
      log('lspclient', lspclient, 'not supported')
      goto continue
    end

    if lspconfig[lspclient].document_config and lspconfig[lspclient].document_config.default_config then
      default_config = lspconfig[lspclient].document_config.default_config
    else
      vim.notify('missing document config for client: ' .. vim.inspect(lspclient), vim.lsp.log_levels.WARN)
      goto continue
    end

    default_config = vim.tbl_deep_extend('force', default_config, ng_default_cfg)
    local cfg = setups[lspclient] or {}

    cfg = vim.tbl_deep_extend('keep', cfg, default_config)
    -- filetype disabled
    if not vim.tbl_contains(cfg.filetypes or {}, ft) then
      trace('ft', ft, 'disabled for', lspclient)

      goto continue
    end

    local disable_fmt = false

    log(lspclient)
    -- if user provides override values
    -- cfg.capabilities = capabilities
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
      if config.combined_attach == 'mine' then
        if config.on_attach == nil then
          error('on attach not provided')
        end
        cfg.on_attach = function(client, bufnr)
          config.on_attach(client, bufnr)

          setup_fmt(client, enable_fmt)
          require('navigator.lspclient.mapping').setup({
            client = client,
            bufnr = bufnr,
            cap = capabilities,
          })
        end
      end
      if config.combined_attach == 'their' then
        cfg.on_attach = function(client, bufnr)
          on_attach(client, bufnr)
          config.on_attach(client, bufnr)
          setup_fmt(client, enable_fmt)
          require('navigator.lspclient.mapping').setup({
            client = client,
            bufnr = bufnr,
            cap = capabilities,
          })
        end
      end
      if config.combined_attach == 'both' then
        cfg.on_attach = function(client, bufnr)
          setup_fmt(client, enable_fmt)

          if config.on_attach and type(config.on_attach) == 'function' then
            config.on_attach(client, bufnr)
          end
          if setups[lspclient] and setups[lspclient].on_attach then
            setups[lspclient].on_attach(client, bufnr)
          else
            on_attach(client, bufnr)
          end
          require('navigator.lspclient.mapping').setup({
            client = client,
            bufnr = bufnr,
            cap = capabilities,
          })
        end
      end
      cfg.on_init = function(client)
        if client and client.config and client.config.settings then
          client.notify(
            'workspace/didChangeConfiguration',
            { settings = client.config.settings },
            vim.lsp.log_levels.WARN
          )
        end
      end
    else
      cfg.on_attach = function(client, bufnr)
        on_attach(client, bufnr)

        setup_fmt(client, enable_fmt)
      end
    end

    log('loading', lspclient, 'name', lspconfig[lspclient].name, 'has lspinst', has_lspinst)
    -- start up lsp
    if has_lspinst and _NgConfigValues.lsp_installer then
      local installed, installer_cfg = require('nvim-lsp-installer.servers').get_server(lspconfig[lspclient].name)

      log('lsp installer server config ' .. lspconfig[lspclient].name, installer_cfg)
      if installed and installer_cfg then
        local paths = installer_cfg:get_default_options().cmd_env and installer_cfg:get_default_options().cmd_env.PATH
        if not paths then
          -- for some reason lspinstaller does not install the binary, check default PATH
          log('lsp installer does not install the lsp in its path, fallback')
          return load_cfg(ft, lspclient, cfg, loaded)
        end
        paths = vim.split(paths, ':')
        if vfn.empty(cfg.cmd) == 1 then
          cfg.cmd = { installer_cfg.name }
        end

        if vfn.executable(cfg.cmd[1]) == 0 then
          for _, path in ipairs(paths) do
            log(path)
            if vfn.isdirectory(path) == 1 and string.find(path, installer_cfg.root_dir) then
              cfg.cmd[1] = path .. path_sep .. cfg.cmd[1]
              log(cfg.cmd)
              break
            end
          end
          log('update cmd', cfg.cmd)
        else
          log('cmd installed', cfg.cmd)
        end
      end
    end
    if has_mason and _NgConfigValues.mason then
      local servers = require'mason-lspconfig'.get_installed_servers()
      if not vim.tbl_contains(servers, lspconfig[lspclient].name) then
        log('mason server not installed', lspconfig[lspclient].name)
        return
      end
     local pkg_name = require "mason-lspconfig.mappings.server".lspconfig_to_package[lspconfig[lspclient].name]
     local pkg = require "mason-registry".get_package(pkg_name)


      log('lsp installer server config ' .. lspconfig[lspclient].name, pkg)
      if pkg then
        local path = pkg:get_install_path()
        if not path then
          -- for some reason lspinstaller does not install the binary, check default PATH
          log('lsp installer does not install the lsp in its path, fallback')
          return load_cfg(ft, lspclient, cfg, loaded)
        end

        cfg.cmd = cfg.cmd or {}
        cfg.cmd[1] = path .. path_sep .. pkg.name
        if vfn.executable(cfg.cmd[1]) == 0 then
          log('failed to find cmd', cfg.cmd[1])
        else
          log('cmd installed', cfg.cmd)
        end
      end
    end


    if vfn.executable(cfg.cmd[1]) == 0 then
      log('lsp server not installed in path ' .. lspclient .. vim.inspect(cfg.cmd), vim.lsp.log_levels.WARN)
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
      vim.defer_fn(function()
        lspconfig['null-ls'].setup(cfg) -- adjust null_ls startup timing
      end, 1000)
      log('null-ls loading')
      _NG_Loaded['null-ls'] = true
      setups['null-ls'] = cfg
    end
  end

  if not _NG_Loaded['efm'] then
    local efm_cfg = user_lsp_opts['efm']
    if efm_cfg then
      local cfg = {}
      cfg = vim.tbl_deep_extend('keep', cfg, efm_cfg)
      cfg.on_attach = function(client, bufnr)
        if efm_cfg.on_attach then
          efm_cfg.on_attach(client, bufnr)
        end
        on_attach(client, bufnr)
      end

      lspconfig.efm.setup(cfg)
      log('efm loading')
      _NG_Loaded['efm'] = true
      setups['efm'] = cfg
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
  end
end

local function setup(user_opts, cnt)
  user_opts = user_opts or {}
  local ft = vim.bo.filetype
  local bufnr = user_opts.bufnr or vim.api.nvim_get_current_buf()
  if ft == '' or ft == nil then
    log('nil filetype, callback')
    local ext = vfn.expand('%:e')
    if ext ~= '' then
      cnt = cnt or 0
      local opts = vim.deepcopy(user_opts)
      if cnt > 3 then
        log('failed to load filetype, skip')
        return
      else
        cnt = cnt + 1
      end
      vim.defer_fn(function()
        log('defer_fn', ext, ft)
        setup(opts, cnt)
      end, 200)
      return
    else
      log('no filetype, no ext return')
      return
    end
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

  local clients = vim.lsp.buf_get_clients(bufnr)
  for key, client in pairs(clients) do
    if client.name ~= 'null_ls' and client.name ~= 'efm' then
      if vim.tbl_contains(client.filetypes or {}, vim.o.ft) then
        log('client already loaded', client.name)
      end
    end
  end

  user_opts = vim.tbl_extend('keep', user_opts, config) -- incase setup was triggered from autocmd

  log('running lsp setup', ft, bufnr)
  local retry = true

  log('loading for ft ', ft, uri)
  highlight.diagnositc_config_sign()
  highlight.add_highlight()
  local lsp_opts = user_opts.lsp or {}

  if vim.bo.filetype == 'lua' then
    local slua = lsp_opts.sumneko_lua
    if slua and not slua.cmd then
      if slua.sumneko_root_path and slua.sumneko_binary then
        lsp_opts.sumneko_lua.cmd = {
          slua.sumneko_binary,
          '-E',
          slua.sumneko_root_path .. '/main.lua',
        }
      else
        lsp_opts.sumneko_lua.cmd = { 'lua-language-server' }
      end
    end
  end

  lsp_startup(ft, retry, lsp_opts)

  --- if code lens enabled
  if _NgConfigValues.lsp.code_lens_action.enable then
    require('navigator.codelens').setup(bufnr)
  end

  -- _LoadedFiletypes[ft .. tostring(bufnr)] = true -- may prevent lsp config when reboot lsp
end

local function on_filetype()
  local bufnr = vim.api.nvim_get_current_buf()
  local uri = vim.uri_from_bufnr(bufnr)

  local ft = vim.bo.filetype
  if ft == nil then
    return
  end
  if uri == 'file://' or uri == 'file:///' then
    trace('skip loading for ft ', ft, uri)
    return
  end

  log (_NG_Loaded)
  if _NG_Loaded[bufnr] and type(_NG_Loaded[bufnr]) == 'number' and _NG_Loaded[bufnr] > 1 then
    log('navigator was loaded for ft', ft, bufnr)
    return
  end

  -- on_filetype should only be trigger only once for each bufnr
  if _NG_Loaded[bufnr] ~= nil and type(_NG_Loaded[bufnr] == 'number')  then
    _NG_Loaded[bufnr] = _NG_Loaded[bufnr] + 1   -- do not hook and trigger filetype event multiple times
  end
  if _NG_Loaded[bufnr] == true then
    _NG_Loaded[bufnr] = 1 -- record the count
  end

  -- as setup will send  filetype event as well
  log(uri)

  local wids = vfn.win_findbuf(bufnr)
  if empty(wids) then
    log('buf not shown return')
  end
  setup({ bufnr = bufnr })
  _NG_Loaded[bufnr] = 1
end

return {
  setup = setup,
  get_cfg = get_cfg,
  add_servers = add_servers,
  on_filetype = on_filetype,
  disabled_ft = disabled_ft,
  ft_disabled = ft_disabled,
}
