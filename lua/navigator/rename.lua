local M = {}
local util = require('navigator.util')
local log = util.log
local api = vim.api
local vfn = vim.fn

local make_position_params = vim.lsp.util.make_position_params
local rename_group = api.nvim_create_augroup('nav-rename', {})

-- local rename_prompt = 'Rename -> '

M.default_config = {
  cmd_name = 'IncRename',
  hl_group = 'Substitute',
  preview_empty_name = false,
  show_message = true,
  input_buffer_type = nil,
  post_hook = nil,
}

local state = {
  should_fetch_references = true,
  cached_lines = nil,
  input_win_id = nil,
  input_bufnr = nil,
  confirm = nil,
  oldname = nil,
  err = nil,
}
local backspace = api.nvim_replace_termcodes('<bs>', true, false, true)

local ns = api.nvim_create_namespace('nav-rename')

local function set_error(msg, level)
  state.err = { msg = msg, level = level }
  state.cached_lines = nil
end

local function ts_symbol()
  local ok, _ = pcall(require, 'nvim-treesitter')
  if not ok then
    vim.notify('treesitter not installed')
    -- try best
    return true
  end

  local bufnr = api.nvim_get_current_buf()
  local queries = require('nvim-treesitter.query')
  local ft_to_lang = require('nvim-treesitter.parsers').ft_to_lang

  local lang = ft_to_lang(vim.bo[bufnr].filetype)
  local query = queries.get_query(lang, 'highlights')

  local ts_utils = require('nvim-treesitter.ts_utils')
  local current_node = ts_utils.get_node_at_cursor()
  if not current_node then
    return false
  end
  local start_row, _, end_row, _ = current_node:range()
  for id, _, _ in query:iter_captures(current_node, 0, start_row, end_row) do
    local name = query.captures[id]
    if name:find('builtin') or name:find('keyword') then
      return false
    end
  end
  return true
end

local function visible(bufnr)
  if api.nvim_buf_is_loaded(bufnr) then
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
      if api.nvim_win_get_buf(win) == bufnr then
        return true
      end
    end
  end
  return false
end

local function hash(a, b, c)
  local cantor = function(x, y)
    return (x + y + 1) * (x + y) / 2 + y
  end
  return cantor(a, cantor(b, c))
end

local function cache_lines(result)
  local cached_lines = {}
  local exists = {}
  for _, res in ipairs(result) do
    local range = res.range
    if range.start.line == range['end'].line then
      local bufnr
      if res.uri then
        bufnr = vim.uri_to_bufnr(res.uri)
      else
        bufnr = vim.api.nvim_get_current_buf()
      end
      if visible(bufnr) then
        if not cached_lines[bufnr] then
          cached_lines[bufnr] = {}
        end
        if not exists[bufnr] then
          exists[bufnr] = {}
        end

        local line_nr = range.start.line
        local line = api.nvim_buf_get_lines(bufnr, line_nr, line_nr + 1, false)[1]
        local start_col, end_col = range.start.character, range['end'].character
        local line_info = { text = line, start_col = start_col, end_col = end_col }
        local h = hash(line_nr, start_col, end_col)
        if not exists[bufnr][h] then
          if cached_lines[bufnr][line_nr] then
            table.insert(cached_lines[bufnr][line_nr], line_info)
          else
            cached_lines[bufnr][line_nr] = { line_info }
          end
          exists[bufnr][h] = true
        end

        -- log(cached_lines[bufnr])
      end
    end
  end
  return cached_lines
end

-- Get positions of LSP reference symbols
local function fetch_lsp_references(bufnr, lsp_params, callback)
  local clients = vim.lsp.get_active_clients({
    bufnr = bufnr,
  })
  clients = vim.tbl_filter(function(client)
    return client.supports_method('textDocument/rename')
  end, clients)

  if #clients == 0 then
    return log('[nav-rename] No active language server with rename capability')
  end

  local params = lsp_params or make_position_params()
  params.context = { includeDeclaration = true }

  log(bufnr, params)

  vim.lsp.buf_request(bufnr, 'textDocument/references', params, function(err, result, _, _)
    -- vim.lsp.buf_request(bufnr, 'textDocument/references', params, function(err, result, _, _)
    if err then
      log('[nav-rename] Error while finding references: ' .. err.message)
      return
    end
    if not result or vim.tbl_isempty(result) then
      log('[nav-rename] Nothing to rename', result)
      return
    end
    state.cached_lines = cache_lines(result)
    state.should_fetch_references = false
    if callback then
      callback()
    end
    log(state.cached_lines)
  end)
end

local function teardown(switch_buffer)
  state.cached_lines = nil
  state.should_fetch_references = true
  state.oldname = nil
  state.newname = nil
  if state.input_win_id and api.nvim_win_is_valid(state.input_win_id) then
    M.config.input_buffer.close_window()
    state.input_win_id = nil
    if switch_buffer then
      api.nvim_set_current_win(state.win_id)
    end
  end
end

local function restore_buffer()
  for bufnr, line_info_per_bufnr in pairs(state.cached_lines or {}) do
    for line_nr, line_info in pairs(line_info_per_bufnr) do
      log(line_nr, line_info[1].text)
      api.nvim_buf_set_lines(bufnr, line_nr, line_nr + 1, false, { line_info[1].text })
    end
  end
end

-- Called when the user is still typing the command or the command arguments
-- a function from smjonas/inc-rename.nvim
local function incremental_rename_preview(opts, preview_ns, preview_buf)
  log(opts, preview_ns, preview_buf)
  local new_name = opts.args

  state.new_name = new_name
  vim.v.errmsg = ''

  if state.input_win_id and api.nvim_win_is_valid(state.input_win_id) then
    -- Add a space so the cursor can be placed after the last character
    api.nvim_buf_set_lines(state.input_bufnr, 0, -1, false, { new_name .. ' ' })
    local _, cmd_prefix_len = vim.fn.getcmdline():find('^%s*' .. M.config.cmd_name .. '%s*')
    local cursor_pos = vim.fn.getcmdpos() - cmd_prefix_len - 1
    -- Create a fake cursor in the input buffer
    api.nvim_buf_add_highlight(state.input_bufnr, preview_ns, 'Visual', 0, cursor_pos, cursor_pos + 1)
  end

  if state.should_fetch_references then
    fetch_lsp_references(preview_buf, state.lsp_params, function()
      incremental_rename_preview(opts, preview_ns, preview_buf)
    end)
  end

  if not state.cached_lines then
    log('lsp references not fetched yet')
    return M.input_buffer ~= nil and 2
  end

  local function apply_highlights_fn(bufnr, line_nr, line_info)
    local offset = 0
    local updated_line = line_info[1].text
    local highlight_positions = {}

    for _, info in ipairs(line_info) do
      updated_line = updated_line:sub(1, info.start_col + offset)
        .. new_name
        .. updated_line:sub(info.end_col + 1 + offset)

      table.insert(highlight_positions, {
        start_col = info.start_col + offset,
        end_col = info.start_col + #new_name + offset,
      })
      -- Offset by the length difference between the new and old names
      offset = offset + #new_name - (info.end_col - info.start_col)
    end

    api.nvim_buf_set_lines(bufnr or opts.bufnr, line_nr, line_nr + 1, false, { updated_line })

    for _, hl_pos in ipairs(highlight_positions) do
      api.nvim_buf_add_highlight(bufnr or opts.bufnr, preview_ns, 'Visual', line_nr, hl_pos.start_col, hl_pos.end_col)
    end
  end

  for bufnr, line_info_per_bufnr in pairs(state.cached_lines) do
    for line_nr, line_info in pairs(line_info_per_bufnr) do
      apply_highlights_fn(bufnr, line_nr, line_info)
    end
  end

  state.preview_ns = preview_ns
  return 2
end

-- Sends a LSP rename request and optionally displays a message to the user showing
-- how many instances were renamed in how many files
local function perform_lsp_rename(new_name, params)
  params = params or make_position_params()
  params.newName = new_name

  vim.lsp.buf_request(0, 'textDocument/rename', params, function(err, result, ctx, _)
    if err and err.message then
      vim.notify('[nav-rename] Error while renaming: ' .. err.message, vim.lsp.log_levels.ERROR)
      return
    end

    if not result or vim.tbl_isempty(result) then
      set_error('[nav-rename] Nothing renamed', vim.lsp.log_levels.WARN)
      return
    end

    local client = vim.lsp.get_client_by_id(ctx.client_id)
    vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)

    if M.config and M.config.show_message then
      local changed_instances = 0
      local changed_files = 0

      local with_edits = result.documentChanges ~= nil
      for _, change in pairs(result.documentChanges or result.changes) do
        changed_instances = changed_instances + (with_edits and #change.edits or #change)
        changed_files = changed_files + 1
      end

      local message = string.format(
        'Renamed %s instance%s in %s file%s',
        changed_instances,
        changed_instances == 1 and '' or 's',
        changed_files,
        changed_files == 1 and '' or 's'
      )
      vim.notify(message)
    end
    if M.config and M.config.post_hook then
      M.config.post_hook(result)
    end
  end)
end

local function inc_rename_execute(opts)
  if vim.v.errmsg ~= '' then
    log('[nav-rename] An error occurred in the preview function.' .. vim.v.errmsg, vim.lsp.log_levels.ERROR)
  elseif state.err then
    log(state.err.msg, state.err.level)
  end
  restore_buffer()
  teardown(true)
  perform_lsp_rename(opts.args, opts.params)
end

M.rename = function()
  local input = vim.ui.input
  vim.ui.input = require('guihua.floating').input
  vim.lsp.buf.rename()
  vim.defer_fn(function()
    vim.ui.input = input
  end, 1000)
end

M.rename_preview = function()
  local input = vim.ui.input

  if not ts_symbol() then
    return
  end

  rename_group = api.nvim_create_augroup('nav-rename', {})
  if vim.fn.has('nvim-0.8.0') ~= 1 then
    vim.ui.input = require('guihua.floating').input
    vim.lsp.buf.rename()
    return vim.defer_fn(function()
      vim.ui.input = input
    end, 1000)
  end

  local ghinput = require('guihua.input')
  state.win_id = vim.fn.win_getid(0)
  state.lsp_params = make_position_params()
  state.preview_buf = vim.api.nvim_get_current_buf()
  ghinput.setup({
    on_change = function(new_name)
      incremental_rename_preview({ args = new_name }, ns, state.preview_buf)
    end,
    preview_buf = state.preview_buf,
    on_confirm = function(new_name)
      -- put back everything
      log('on_confirm', new_name)
      restore_buffer()
    end,
    on_cancel = function(new_name)
      restore_buffer()
      teardown(true)
      log('cancel', new_name)
    end,
  })
  vim.ui.input = ghinput.input

  vim.lsp.buf.rename()
end

-- rename withou floating window
function M.rename_inplace(new_name, options)
  options = options or {}

  rename_group = api.nvim_create_augroup('nav-rename', {})
  local bufnr = options.bufnr or api.nvim_get_current_buf()
  local clients = vim.lsp.get_active_clients({
    bufnr = bufnr,
    name = options.name,
  })
  if options.filter then
    clients = vim.tbl_filter(options.filter, clients)
  end

  if not ts_symbol() then
    return
  end

  -- Clients must at least support rename, prepareRename is optional
  clients = vim.tbl_filter(function(client)
    return client.supports_method('textDocument/rename')
  end, clients)

  if #clients == 0 then
    vim.notify('[LSP] Rename, no matching language servers with rename capability.')
  end

  local win = api.nvim_get_current_win()

  -- Compute early to account for cursor movements after going async
  local cword = vim.fn.expand('<cword>')

  ---@private
  local function get_text_at_range(range, offset_encoding)
    return api.nvim_buf_get_text(
      bufnr,
      range.start.line,
      util._get_line_byte_from_position(bufnr, range.start, offset_encoding),
      range['end'].line,
      util._get_line_byte_from_position(bufnr, range['end'], offset_encoding),
      {}
    )[1]
  end

  local try_use_client
  try_use_client = function(idx, client)
    if not client then
      return
    end

    local params = make_position_params(win, client.offset_encoding)
    ---@private
    local function rename(name)
      params.newName = name
      local handler = client.handlers['textDocument/rename'] or vim.lsp.handlers['textDocument/rename']
      client.request('textDocument/rename', params, function(...)
        handler(...)
        try_use_client(next(clients, idx))
      end, bufnr)
    end

    if client.supports_method('textDocument/prepareRename') then
      -- log(params)
      client.request('textDocument/prepareRename', params, function(err, result)
        if err or result == nil then
          if next(clients, idx) then
            try_use_client(next(clients, idx))
          else
            local msg = err and ('Error on prepareRename: ' .. (err.message or '')) or 'Nothing to rename'
            vim.notify(msg, vim.log.levels.INFO)
          end
          return
        end

        incremental_rename_preview({ args = vim.fn.expand('<cword>'), floating = false }, 0, bufnr)
        if new_name then
          return rename(new_name)
        end

        vim.api.nvim_create_autocmd({ 'TextChangedI' }, {
          group = rename_group,
          callback = function()
            local w = vim.fn.expand('<cword>')
            local curl = vfn.getline('.')
            local curc = curl:sub(vfn.col('.'), vfn.col('.'))
            if curc:match('%s') then
              local cur_pos = vim.fn.getpos('.')
              cur_pos[3] = cur_pos[3] - 1
              vfn.setpos('.', cur_pos)
              log('move back')
              w = vim.fn.expand('<cword>')
              cur_pos[3] = cur_pos[3] + 1
              vfn.setpos('.', cur_pos)
            end
            log(curc, w)
            incremental_rename_preview({ args = w, floating = false }, ns, bufnr)
          end,
        })
        vim.keymap.set('i', '<S-CR>', function()
          print('done rename')
          local input = vim.fn.expand('<cword>')
          log('newname', input)
          state.confirm = true
          vim.cmd('stopinsert')
        end, { buffer = bufnr })

        vim.api.nvim_create_autocmd({ 'InsertLeave' }, {
          group = rename_group,
          callback = function()
            log('leave insert')
            api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
            api.nvim_del_augroup_by_name('nav-rename')
            vim.keymap.del('i', '<S-CR>', { buffer = bufnr })
            restore_buffer()
            if state.confirm then
              -- lets put back
              log('execute rename')
              inc_rename_execute({ args = state.new_name or vim.fn.expand('<cword>'), params = params })
            end
          end,
        })

        vim.cmd('noautocmd startinsert')
        -- no need
        -- vim.ui.input(prompt_opts, function(input)
        --   if not input or #input == 0 then
        --     return
        --   end
        --   rename(input)
        -- end)
      end, bufnr)
    else
      assert(client.supports_method('textDocument/rename'), 'Client must support textDocument/rename')
      if new_name then
        rename(new_name)
        return
      end

      local prompt_opts = {
        prompt = 'New Name: ',
        default = cword,
      }
      vim.ui.input(prompt_opts, function(input)
        if not input or #input == 0 then
          return
        end
        rename(input)
      end)
    end
  end

  try_use_client(next(clients))
end

return M
