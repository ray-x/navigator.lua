local M = {}
local api = vim.api

local function warn(msg)
  api.nvim_echo({ { 'WRN: ' .. msg, 'WarningMsg' } }, true, {})
end

local function info(msg)
  if _NgConfigValues.debug then
    api.nvim_echo({ { 'Info: ' .. msg } }, true, {})
  end
end

_NgConfigValues = {
  debug = false, -- log output
  width = 0.62, -- valeu of cols
  height = 0.38, -- listview height
  preview_height = 0.38,
  preview_lines = 40, -- total lines in preview screen
  preview_lines_before = 5, -- lines before the highlight line
  default_mapping = true,
  keymaps = {}, -- e.g keymaps={{key = "GR", func = vim.lsp.buf.references}, } this replace gr default mapping
  external = nil, -- true: enable for goneovim multigrid otherwise false

  border = 'single', -- border style, can be one of 'none', 'single', 'double', "shadow"
  lines_show_prompt = 10, -- when the result list items number more than lines_show_prompt,
  -- fuzzy finder prompt will be shown
  combined_attach = 'both', -- both: use both customized attach and navigator default attach, mine: only use my attach defined in vimrc
  on_attach = function(client, bufnr)
    -- your on_attach will be called at end of navigator on_attach
  end,
  ts_fold = false,
  treesitter_analysis = true, -- treesitter variable context
  treesitter_analysis_max_num = 100, -- how many items to run treesitter analysis
  treesitter_analysis_condense = true, -- short format of function
  transparency = 50, -- 0 ~ 100 blur the main window, 100: fully transparent, 0: opaque,  set to nil to disable it
  lsp_signature_help = true, -- if you would like to hook ray-x/lsp_signature plugin in navigator
  -- setup here. if it is nil, navigator will not init signature help
  signature_help_cfg = { debug = false }, -- if you would like to init ray-x/lsp_signature plugin in navigator, pass in signature help
  ctags = {
    cmd = 'ctags',
    tagfile = '.tags',
    options = '-R --exclude=.git --exclude=node_modules --exclude=test --exclude=vendor --excmd=number',
  },
  lsp = {
    enable = true, -- if disabled make sure add require('navigator.lspclient.mapping').setup() in you on_attach
    code_action = {
      enable = true,
      sign = true,
      sign_priority = 40,
      virtual_text = true,
      virtual_text_icon = true,
    },
    document_highlight = true, -- highlight reference a symbol
    code_lens_action = {
      enable = true,
      sign = true,
      sign_priority = 40,
      virtual_text = true,
      virtual_text_icon = true,
    },
    diagnostic = {
      underline = true,
      virtual_text = { spacing = 3, source = true }, -- show virtual for diagnostic message
      update_in_insert = false, -- update diagnostic message in insert mode
      severity_sort = { reverse = true },
    },
    format_on_save = true, -- set to false to disasble lsp code format on save (if you are using prettier/efm/formater etc)
    format_options = { async = false }, -- async: disable by default, I saw something unexpected
    disable_nulls_codeaction_sign = true, -- do not show nulls codeactions (as it will alway has a valid action)
    disable_format_cap = {}, -- a list of lsp disable file format (e.g. if you using efm or vim-codeformat etc), empty by default
    disable_lsp = {}, -- a list of lsp server disabled for your project, e.g. denols and tsserver you may
    -- only want to enable one lsp server
    disply_diagnostic_qf = true, -- always show quickfix if there are diagnostic errors
    diagnostic_load_files = false, -- lsp diagnostic errors list may contains uri that not opened yet set to true
    -- to load those files
    diagnostic_virtual_text = true, -- show virtual for diagnostic message
    diagnostic_update_in_insert = false, -- update diagnostic message in insert mode
    diagnostic_scrollbar_sign = { '▃', '▆', '█' }, -- set to nil to disable, set to {'╍', 'ﮆ'} to enable diagnostic status in scroll bar area
    tsserver = {
      -- filetypes = {'typescript'} -- disable javascript etc,
      -- set to {} to disable the lspclient for all filetype
    },
    ['lua-dev'] = { -- navigator can use lua-dev settings to setup sumneko_lua
      -- your setting for lua-dev here
      -- navigator will setup lua-dev
    },
    sumneko_lua = {
      -- sumneko_root_path = sumneko_root_path,
      -- sumneko_binary = sumneko_binary,
      -- cmd = {'lua-language-server'}
    },
    servers = {}, -- you can add additional lsp server so navigator will load the default for you
  },
  lsp_installer = false, -- set to true if you would like use the lsp installed by williamboman/nvim-lsp-installer
  mason = false, -- set to true if you would like use the lsp installed by williamboman/mason
  icons = {
    icons = true, -- set to false to use system default ( if you using a terminal does not have nerd/icon)
    -- Code action
    code_action_icon = '🏏', -- "",
    -- code lens
    code_lens_action_icon = '👓',
    -- Diagnostics
    diagnostic_head = '🐛',
    diagnostic_err = '📛',
    diagnostic_warn = '👎',
    diagnostic_info = [[👩]],
    diagnostic_hint = [[💁]],

    diagnostic_head_severity_1 = '🈲',
    diagnostic_head_severity_2 = '☣️',
    diagnostic_head_severity_3 = '👎',
    diagnostic_head_description = '👹',
    diagnostic_virtual_text = '🦊',
    diagnostic_file = '🚑',
    -- Values
    value_changed = '📝',
    value_definition = '🐶🍡', -- it is easier to see than 🦕
    side_panel = {
      section_separator = '',
      line_num_left = '',
      line_num_right = '',
      inner_node = '├○',
      outer_node = '╰○',
      bracket_left = '⟪',
      bracket_right = '⟫',
    },
    -- Treesitter
    match_kinds = {
      var = ' ', -- "👹", -- Vampaire
      method = 'ƒ ', --  "🍔", -- mac
      ['function'] = ' ', -- "🤣", -- Fun
      parameter = '  ', -- Pi
      associated = '🤝',
      namespace = '🚀',
      type = ' ',
      field = '🏈',
      module = '📦',
      flag = '🎏',
    },
    treesitter_defult = '🌲',
    doc_symbols = '',
  },
}

M.deprecated = function(cfg)
  if cfg.code_action_prompt then
    warn('code_action_prompt moved to lsp.code_action')
  end
  if cfg.code_lens_action_prompt then
    warn('code_lens_action_prompt moved to lsp.code_lens_action')
  end

  if cfg.lsp ~= nil and cfg.lsp.disable_format_ft ~= nil and cfg.lsp.disable_format_ft ~= {} then
    warn('disable_format_ft renamed to disable_format_cap')
  end

  if cfg.lsp ~= nil and cfg.lsp.code_lens == true then
    warn('code_lens moved to lsp.code_lens_action')
  end

  if cfg.lspinstall ~= nil then
    warn('lspinstall deprecated, please use lsp-installer instead or use "lspinstall" branch')
  end
end

local extend_config = function(opts)
  opts = opts or {}
  if next(opts) == nil then
    return
  end
  if opts.debug then
    _NgConfigValues.debug = opts.debug
  end
  -- enable logs
  require('navigator.util').setup()
  for key, value in pairs(opts) do
    if _NgConfigValues[key] == nil then
      warn(
        string.format(
          '[] Deprecated? Key %s is not in default setup, it could be incorrect to set to %s',
          key,
          vim.inspect(value)
        )
      )
      _NgConfigValues[key] = value
      -- return
    else
      if type(_NgConfigValues[key]) == 'table' then
        if type(value) ~= 'table' then
          info(
            string.format(
              '[] Reset type: Key %s setup value %s type %s , from %s',
              key,
              vim.inspect(value),
              type(value),
              vim.inspect(_NgConfigValues[key])
            )
          )
        end
        for k, v in pairs(value) do
          if type(k) == 'number' then
            -- replace all item in array
            _NgConfigValues[key] = value
            break
          end
          -- level 3
          if type(_NgConfigValues[key][k]) == 'table' then
            if type(v) == 'table' then
              for k2, v2 in pairs(v) do
                _NgConfigValues[key][k][k2] = v2
              end
            else
              _NgConfigValues[key][k] = v
            end
          else
            if _NgConfigValues[key][k] == nil then
              if key == 'lsp' then
                local lsp = require('navigator.lspclient.servers')
                if not vim.tbl_contains(lsp or {}, k) and k ~= 'efm' and k ~= 'null-ls' then
                  info(string.format('[] extend LSP support for  %s %s ', key, k))
                end
              elseif key == 'keymaps' then
                info('keymap override' .. vim.inspect(v))
                -- skip key check and allow mapping to handle that
              else
                warn(string.format('[] Key %s %s not valid', key, k))
              end
              -- return
            end
            _NgConfigValues[key][k] = v
          end
        end
      else
        _NgConfigValues[key] = value
      end
    end
  end
  if _NgConfigValues.sumneko_root_path or _NgConfigValues.sumneko_binary then
    vim.notify("Please put sumneko setup in lsp['sumneko_lua']", vim.log.levels.WARN)
  end

  M.deprecated(opts)
end

M.config_values = function()
  return _NgConfigValues
end

M.setup = function(cfg)
  cfg = cfg or {}
  extend_config(cfg)

  local cmd_group = api.nvim_create_augroup('NGFtGroup', {})
  api.nvim_create_autocmd({ 'FileType', 'BufEnter' }, {
    group = cmd_group,
    pattern = '*',
    callback = function()
      require('navigator.lspclient.clients').on_filetype()
    end,
  })
  require('navigator.lazyloader').init()
  require('navigator.lspclient.clients').setup(_NgConfigValues)

  require('navigator.reference')
  require('navigator.definition')
  require('navigator.hierarchy')
  require('navigator.implementation')

  cfg.lsp = cfg.lsp or _NgConfigValues.lsp

  if _NgConfigValues.lsp.enable then
    require('navigator.diagnostics').config(cfg.lsp.diagnostic)
  end
  if not _NgConfigValues.loaded then
    _NgConfigValues.loaded = true
  end

  if _NgConfigValues.ts_fold == true then
    local ok, _ = pcall(require, 'nvim-treesitter')
    if ok then
      require('navigator.foldts').on_attach()
    end
  end

  local _start_client = vim.lsp.start_client
  vim.lsp.start_client = function(lsp_config)
    -- add highlight for Lspxxx
    require('navigator.lspclient.highlight').add_highlight()
    require('navigator.lspclient.highlight').diagnositc_config_sign()
    -- require('navigator.lspclient.mapping').setup()
    require('navigator.lspclient.lspkind').init()
    return _start_client(lsp_config)
  end
end

return M
