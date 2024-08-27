local M = {}
local api = vim.api

local function warn(msg)
  api.nvim_echo({ { 'WRN: ' .. msg, 'WarningMsg' } }, true, {})
end

local function info(msg)
  if _NgConfigValues.debug then
    api.nvim_echo({ { 'Debug: ' .. msg } }, true, {})
  end
end

_NgConfigValues = {
  debug = false, -- log output
  width = 0.75, -- value of cols
  height = 0.38, -- listview height
  preview_height = 0.38,
  preview_lines = 40, -- total lines in preview screen
  preview_lines_before = 5, -- lines before the highlight line
  default_mapping = true,
  keymaps = {}, -- e.g keymaps={{key = "GR", func = vim.lsp.buf.references}, } this replace gr default mapping
  external = nil, -- true: enable for goneovim multigrid otherwise false

  border = 'single', -- border style, can be one of 'none', 'single', 'double', "shadow"
  lines_show_prompt = 10, -- when the result list items number more than lines_show_prompt,
  prompt_mode = 'insert', -- 'normal' | 'insert'
  -- fuzzy finder prompt will be shown
  combined_attach = 'both', -- both: use both customized attach and navigator default attach, mine: only use my attach defined in vimrc
  on_attach = function(client, bufnr)
    -- your on_attach will be called at end of navigator on_attach
  end,
  -- ts_fold = false, -- deprecated
  ts_fold = {
    enable = false,
    comment = true, -- ts fold text object
    max_lines_scan_comments = 2000, -- maximum lines to scan for comments
    disable_filetypes = { 'help', 'text', 'markdown' }, -- disable ts fold for specific filetypes
  },
  treesitter_analysis = true, -- treesitter variable context
  treesitter_navigation = true, -- bool|table
  treesitter_analysis_max_num = 100, -- how many items to run treesitter analysis
  treesitter_analysis_max_fnum = 20, -- how many files to run treesitter analysis
  treesitter_analysis_condense = true, -- short format of function
  treesitter_analysis_depth = 3, -- max depth
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
      delay = 3000, -- how long the virtual text will be shown
      enable = true,
      sign = true,
      sign_priority = 40,
      virtual_text = true,
      virtual_text_icon = true,
      exclude = {},
    },
    rename = {
      enable = true,
      style = 'floating-preview', -- 'floating' | 'floating-preview' | 'inplace-preview'
      show_result = true,
      confirm = '<S-CR>',
      cancel = '<S-ESC>',
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
      enable = true,
      underline = true,
      virtual_text = { spacing = 3, source = true }, -- show virtual for diagnostic message
      update_in_insert = false, -- update diagnostic message in insert mode
      severity_sort = { reverse = true },
      float = {
        focusable = false,
        sytle = 'minimal',
        border = 'rounded',
        source = 'always',
        header = '',
        prefix = '',
      },
    },
    definition = { enable = true },
    call_hierarchy = { enable = true },
    implementation = { enable = true },
    workspace = { enable = true },
    hover = {
      enable = true,
      -- fallback if hover failed
      -- go = function()
      --   local w = vim.fn.expand('<cWORD>')
      --   w = w:gsub('*', '')
      --   vim.cmd('GoDoc ' .. w)
      -- end,
      python = function()
        local w = vim.fn.expand('<cWORD>')
        local setup = {
          'pydoc',
          w,
        }
        return vim.fn.jobstart(setup, {
          on_stdout = function(_, data, _)
            if not data or (#data == 1 and vim.fn.empty(data[1]) == 1) then
              return
            end
            local close_events = { 'CursorMoved', 'CursorMovedI', 'BufHidden', 'InsertCharPre' }
            local config = {
              close_events = close_events,
              focusable = true,
              border = 'single',
              width = 80,
              zindex = 100,
            }
            vim.lsp.util.open_floating_preview(data, 'python', config)
          end,
        })
      end,
      default = function()
        -- local w = vim.fn.expand('<cword>')
        -- print('default ' .. w)
        -- vim.lsp.buf.workspace_symbol(w)
      end,
      -- },
      -- },
    }, -- bind hover action to keymap; there are other options e.g. noice, lspsaga provides lsp hover
    format_on_save = true, -- {true|false} set to false to disasble lsp code format on save (if you are using prettier/efm/formater etc)
    -- table: {enable = {'lua', 'go'}, disable = {'javascript', 'typescript'}} to enable/disable specific language
    -- enable: a whitelist of language that will be formatted on save
    -- disable: a blacklist of language that will not be formatted on save
    -- function: function(bufnr) return true end to enable/disable lsp format on save
    format_options = { async = false }, -- async: disable by default, I saw something unexpected
    disable_nulls_codeaction_sign = true, -- do not show nulls codeactions (as it will alway has a valid action)
    disable_format_cap = {}, -- a list of lsp disable file format (e.g. if you using efm or vim-codeformat etc), empty by default
    disable_lsp = {}, -- a list of lsp server disabled for your project, e.g. denols and tsserver you may
    -- only want to enable one lsp server
    display_diagnostic_qf = false, -- bool: always show quickfix if there are diagnostic errors
    -- string: trouble use trouble to show diagnostic
    diagnostic_load_files = false, -- lsp diagnostic errors list may contains uri that not opened yet set to true
    -- to load those files
    diagnostic_virtual_text = true, -- show virtual for diagnostic message
    diagnostic_update_in_insert = false, -- update diagnostic message in insert mode
    diagnostic_scrollbar_sign = { '▃', '▆', '█' }, -- set to nil to disable, set to {'╍', 'ﮆ'} to enable diagnostic status in scroll bar area
    tsserver = {
      -- filetypes = {'typescript'} -- disable javascript etc,
      -- set to {} to disable the lspclient for all filetype
    },
    neodev = false,
    lua_ls = {
      -- sumneko_root_path = sumneko_root_path,
      -- sumneko_binary = sumneko_binary,
      -- cmd = {'lua-language-server'}
    },
    servers = {}, -- you can add additional lsp server so navigator will load the default for you
  },
  mason = false, -- set to true if you would like use the lsp installed by williamboman/mason
  mason_disabled_for = {}, -- disable mason for specified lspclients
  icons = {
    -- requires Nerd Font or nvim-web-devicons pre-installed
    icons = true, -- set to false to use system default ( if you using a terminal does not have nerd/icon)

    -- Code Action (gutter, floating window)
    code_action_icon = '🏏',

    -- Code Lens (gutter, floating window)
    code_lens_action_icon = '👓',

    -- Diagnostics (gutter)
    diagnostic_head = '🐛', -- prefix for other diagnostic_* icons
    diagnostic_err = '📛',
    diagnostic_warn = '👎',
    diagnostic_info = [[👩]],
    diagnostic_hint = [[💁]],

    -- Diagnostics (floating window)
    diagnostic_head_severity_1 = '🈲',
    diagnostic_head_severity_2 = '🛠️',
    diagnostic_head_severity_3 = '🔧',
    diagnostic_head_description = '👹', -- suffix for severities
    diagnostic_virtual_text = '🦊', -- floating text preview (set to empty to disable)
    diagnostic_file = '🚑', -- icon in floating window, indicates the file contains diagnostics

    -- Values (floating window)
    value_definition = '🐶🍡', -- identifier defined
    value_changed = '📝', -- identifier modified
    context_separator = ' ', -- separator between text and value

    -- Formatting for Side Panel
    side_panel = {
      section_separator = '󰇜',
      line_num_left = '',
      line_num_right = '',
      inner_node = '├○',
      outer_node = '╰○',
      bracket_left = '⟪',
      bracket_right = '⟫',
      tab = '󰌒',
    },
    fold = {
      prefix = '⚡',
      separator = '',
    },

    -- Treesitter
    -- Note: many more node.type or kind may be available
    match_kinds = {
      var = ' ', -- variable -- "👹", -- Vampaire
      const = '󱀍 ',
      method = 'ƒ ', -- method --  "🍔", -- mac
      -- function is a keyword so wrap in ['key'] syntax
      ['function'] = '󰡱 ', -- function -- "🤣", -- Fun
      parameter = '  ', -- param/arg -- Pi
      parameters = '  ', -- param/arg -- Pi
      required_parameter = '  ', -- param/arg -- Pi
      associated = '🤝', -- linked/related
      namespace = '🚀', -- namespace
      type = '󰉿', -- type definition
      field = '🏈', -- field definition
      module = '📦', -- module
      flag = '🎏', -- flag
    },
    treesitter_defult = '🌲', -- default symbol when unknown node.type or kind
    doc_symbols = '', -- document
  },
}

M.deprecated = function(cfg)
  if cfg.ts_fold ~= nil and type(cfg.ts_fold) == 'boolean' then
    warn('ts_fold option changed, refer to README for more details')
    cfg.ts_fold = { enable = cfg.ts_fold }
  end
  local has_nvim_010 = vim.fn.has('nvim-0.10') == 1
  if not has_nvim_010 then
    vim.lsp.get_clients = vim.lsp.get_active_clients
    vim.islist = vim.tbl_islist
  end
  if cfg.lsp and cfg.lsp.hover and cfg.lsp.hover.keymaps then
    warn('lsp.hover.keymaps is deprecated, refer to README for more details')
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
  M.deprecated(opts)
  for key, value in pairs(opts) do
    if _NgConfigValues[key] == nil then
      warn(
        string.format(
          '[󰎐] Deprecated? Key %s is not in default setup, it could be incorrect to set to %s',
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
              '[󰎐] Reset type: Key %s setup value %s type %s , from %s',
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
                -- if not vim.tbl_contains(lsp or {}, k) and k ~= 'efm' and k ~= 'null-ls' then
                --   info(string.format('[󰎐] extend LSP support for  %s %s ', key, k))
                -- end
              elseif key == 'signature_help_cfg' then
                _NgConfigValues[key][k] = v
              elseif key == 'keymaps' then
                info('keymap override' .. vim.inspect(v))
                -- skip key check and allow mapping to handle that
              else
                warn(string.format('[󰎐] Key %s %s not valid', key, k))
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
  -- if _NgConfigValues.sumneko_root_path or _NgConfigValues.sumneko_binary then
  --   vim.notify("Please put sumneko setup in lsp['lua_ls']", vim.log.levels.WARN)
  -- end
end

M.config_values = function()
  return _NgConfigValues
end
local cmd_group

M.setup = function(cfg)
  cfg = cfg or {}
  extend_config(cfg)

  if not cmd_group then
    cmd_group = api.nvim_create_augroup('NGFtGroup', {})
    api.nvim_create_autocmd({ 'FileType', 'BufEnter' }, {
      group = cmd_group,
      pattern = '*',
      callback = function()
        require('navigator.lspclient.clients').on_filetype()
      end,
    })
  end

  vim.defer_fn(function()
    require('navigator.lazyloader').init()
    require('navigator.lspclient.clients').setup(_NgConfigValues)

    require('navigator.reference')
    require('navigator.definition')
    require('navigator.hierarchy')
    require('navigator.implementation')
    local ts_installed = pcall(require, 'nvim-treesitter')
    if not ts_installed then
      if _NgConfigValues.ts_fold.enable == true then
        warn('treesitter not installed ts_fold disabled')
        _NgConfigValues.ts_fold.enable = false
      end
      if _NgConfigValues.treesitter_analysis == true then
        warn('nvim-treesitter not installed, disable treesitter_analysis')
        _NgConfigValues.treesitter_analysis = false
      end
      if _NgConfigValues.treesitter_navigation == true then
        warn('nvim-treesitter not installed, disable treesitter_navigation')
        _NgConfigValues.treesitter_navigation = false
      end
    end
    cfg.lsp = cfg.lsp or _NgConfigValues.lsp

    if _NgConfigValues.lsp.enable then
      require('navigator.diagnostics').config(cfg.lsp.diagnostic)
    end
    if not _NgConfigValues.loaded then
      _NgConfigValues.loaded = true
    end

    if
      _NgConfigValues.ts_fold.enable == true
      and not vim.tbl_contains(_NgConfigValues.ts_fold.disable_filetypes, vim.o.filetype)
      and not vim.wo.diff
    then
      require('navigator.foldts').on_attach()
    end

    local _start_client = vim.lsp.start_client
    vim.lsp.start_client = function(lsp_config)
      -- add highlight for Lspxxx
      require('navigator.lspclient.highlight').add_highlight()
      require('navigator.lspclient.highlight').config_signs()
      -- require('navigator.lspclient.mapping').setup()
      require('navigator.lspclient.lspkind').init()
      return _start_client(lsp_config)
    end
  end, 1)
end

return M
