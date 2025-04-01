-- the preview and cache are copy from
-- smjonas/inc-renamer.nvim
-- https://github.com/smjonas/inc-rename.nvim/blob/main/lua/inc_rename/init.lua
-- inplace rename are from neovim vim.lsp.buf.rename

local util = require('navigator.util')
local log = util.log
local api = vim.api
local vfn = vim.fn

local M = {
  hl_group = 'Substitute',
}
local make_position_params = util.make_position_params
local rename_group = api.nvim_create_augroup('nav-rename', {})

local state = {
  should_fetch_references = true,
  cached_lines = nil,
  input_win_id = nil,
  input_bufnr = nil,
  confirm = nil,
  oldname = nil,
  newname = nil,
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
    return {}
  end

  local bufnr = api.nvim_get_current_buf()
  local queries = require('nvim-treesitter.query')
  local ft_to_lang = require('nvim-treesitter.parsers').ft_to_lang

  local lang = ft_to_lang(vim.bo[bufnr].filetype)
  local query = (vim.fn.has('nvim-0.9') == 1) and vim.treesitter.query.get(lang, 'highlights')
    or vim.treesitter.get_query(lang, 'highlights')

  local ts_utils = require('nvim-treesitter.ts_utils')
  local current_node = ts_utils.get_node_at_cursor()
  if not current_node then
    return
  end
  local start_row, _, end_row, _ = current_node:range()
  for id, _, _ in query:iter_captures(current_node, 0, start_row, end_row) do
    local name = query.captures[id]
    if name:find('builtin') or name:find('keyword') then
      return
    end
  end
  return current_node
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

-- a function from smjonas/inc-rename.nvim
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

local function fetch_lsp_references(bufnr, lsp_params, callback)
  log('fetch_lsp_references', bufnr, lsp_params)
  require('navigator.reference').fetch_lsp_references(
    bufnr,
    lsp_params,
    function(err, result, ctx, cfg)
      if err then
        log('[nav-rename] Error while finding references: ' .. err.message, ctx, cfg)
        return
      end
      if not result or vim.tbl_isempty(result) then
        log('[nav-rename] Nothing to rename', result)
        return
      end
      state.total = #result
      state.cached_lines = cache_lines(result)
      state.should_fetch_references = false
      if callback then
        callback()
      end
    end
  )
end

-- inspired by smjonas/inc-rename.nvim
local function teardown(switch_buffer)
  state.should_fetch_references = true
  state.cached_lines = nil
  state.oldname = nil
  state.newname = nil
  state.lsp_params = nil
  if state.input_win_id and api.nvim_win_is_valid(state.input_win_id) then
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
-- inspired by smjonas/inc-rename.nvim
local function incremental_rename_preview(opts, preview_ns, preview_buf)
  log(opts, preview_ns, preview_buf)
  local new_name = opts.args

  state.new_name = new_name
  vim.v.errmsg = ''

  if state.should_fetch_references then
    fetch_lsp_references(preview_buf, state.lsp_params, function()
      incremental_rename_preview(opts, preview_ns, preview_buf)
    end)
  end

  if not state.cached_lines then
    log('lsp references not fetched yet')
    return
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
      -- api.nvim_buf_add_highlight(
      -- bufnr or opts.bufnr,
      -- preview_ns,
      -- M.hl_group,
      -- line_nr,
      -- hl_pos.start_col,
      -- hl_pos.end_col
      -- )
      api.nvim_buf_set_extmark(bufnr or opts.bufnr, preview_ns, line_nr, hl_pos.start_col, {
        end_line = line_nr,
        end_col = hl_pos.end_col,
        hl_group = M.hl_group,
        priority = 1000,
      })
    end
  end

  for bufnr, line_info_per_bufnr in pairs(state.cached_lines) do
    for line_nr, line_info in pairs(line_info_per_bufnr) do
      apply_highlights_fn(bufnr, line_nr, line_info)
    end
  end

  state.preview_ns = preview_ns
end

local function perform_lsp_rename(opts)
  local new_name = opts.args
  local clients = vim.lsp.get_clients({
    method = 'textDocument/rename',
    bufnr = opts.bufnr,
  })
  if not clients then
    return
  end

  local params = opts.params or state.lsp_params

  clients[1].request('textDocument/rename', params, function(err, result, ctx, _)
    if err and err.message then
      vim.notify('[nav-rename] Error while renaming: ' .. err.message, vim.log.levels.ERROR)
      return
    end

    if not result or vim.tbl_isempty(result) then
      set_error('[nav-rename] Nothing renamed', vim.log.levels.INFO)
      return
    end

    local client = vim.lsp.get_client_by_id(ctx.client_id)
    vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)

    if _NgConfigValues.lsp.rename.show_result then
      local changed_instances = 0
      local changed_files = 0

      local with_edits = result.documentChanges ~= nil
      for _, change in pairs(result.documentChanges or result.changes) do
        changed_instances = changed_instances + (with_edits and #change.edits or #change)
        changed_files = changed_files + 1
      end

      local message = string.format(
        'Renamed %s instance%s %s in %s file%s \n to %s:',
        changed_instances,
        changed_instances == 1 and '' or 's',
        state.oldname,
        changed_files,
        changed_files == 1 and '' or 's',
        new_name
      )
      vim.notify(message)
    end
    if M.config and M.config.post_hook then
      M.config.post_hook(result)
    end
  end, 0)
end

local function inc_rename_execute(opts)
  if vim.v.errmsg ~= '' then
    log(
      '[nav-rename] An error occurred in the preview function.' .. vim.v.errmsg,
      vim.log.levels.ERROR
    )
  elseif state.err then
    log(state.err.msg, state.err.level)
  end
  restore_buffer()
  teardown(true)
  perform_lsp_rename(opts)
end

M.rename = function()
  if _NgConfigValues.lsp.rename.style == 'floating-preview' then
    return M.rename_preview()
  end
  if _NgConfigValues.lsp.rename.style == 'inplace-preview' then
    return M.rename_inplace()
  end

  local input = vim.ui.input

  local ghinput = require('guihua.input')
  -- make sure everything was restored
  ghinput.setup({
    on_change = function(new_name) end,
    on_concel = function(new_name) end,
    title = 'lsp rename',
    on_cancel = function() end,
  })
  vim.ui.input = ghinput.input
  vim.lsp.buf.rename()
  vim.defer_fn(function()
    vim.ui.input = input
  end, 1000)
end

M.rename_preview = function()
  local input = vim.ui.input
  state.cached_lines = {}
  state.confirm = nil
  state.should_fetch_references = true
  local clients = vim.lsp.get_clients({
    bufnr = api.nvim_get_current_buf(),
    method = 'textDocument/rename',
  })

  if not clients or not ts_symbol() then
    return
  end

  state.lsp_params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)

  rename_group = api.nvim_create_augroup('nav-rename', {})
  local ghinput = require('guihua.input')
  state.win_id = vim.fn.win_getid(0)
  state.preview_buf = vim.api.nvim_get_current_buf()

  local inputopts = {
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
  }
  if vim.fn.has('nvim-0.9.0') == 1 then
    inputopts.title = 'symbol rename'
  end
  ghinput.setup(inputopts)
  vim.ui.input = ghinput.input

  vim.lsp.buf.rename()
end

-- rename without floating window
-- a moodify version of neovim vim.lsp.buf.rename
function M.rename_inplace(new_name, options)
  options = options or {}
  state.confirm = nil
  state.should_fetch_references = true
  state.cached_lines = {}

  rename_group = api.nvim_create_augroup('nav-rename', {})
  local bufnr = options.bufnr or api.nvim_get_current_buf()

  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    method = 'textDocument/rename',
  })

  if not clients or not ts_symbol() then
    vim.notify('[LSP] Rename, no matching language servers with rename capability.')
    return
  end

  state.lsp_params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)

  local confirm_key = _NgConfigValues.lsp.rename.confirm
  local cancel_key = _NgConfigValues.lsp.rename.concel
  local win = api.nvim_get_current_win()

  -- Compute early to account for cursor movements after going async
  local cword = vim.fn.expand('<cword>')
  state.oldname = cword

  local on_finish_cb = function()
    log('leave insert')

    api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    api.nvim_del_augroup_by_name('nav-rename')
    vim.keymap.del({ 'i', 'n' }, confirm_key, { buffer = bufnr })
    vim.keymap.del({ 'i', 'n' }, cancel_key, { buffer = bufnr })
    restore_buffer()
    if state.confirm then
      -- lets put back
      log('execute rename')
      inc_rename_execute({
        args = state.new_name or vim.fn.expand('<cword>'),
        params = {},
        bufnr = bufnr,
      })
    end
  end
  local try_use_client
  try_use_client = function(idx, client)
    if not client then
      return
    end

    local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
    ---@private
    local function rename(name)
      params.newName = name
      local handler = client.handlers['textDocument/rename']
        or vim.lsp.handlers['textDocument/rename']
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
            local msg = err and ('Error on prepareRename: ' .. (err.message or ''))
              or 'Nothing to rename'
            vim.notify(msg, vim.log.levels.INFO)
          end
          return
        end

        incremental_rename_preview({ args = cword, floating = false }, 0, bufnr)
        if new_name then
          return rename(new_name)
        end

        vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChanged' }, {
          group = rename_group,
          callback = function()
            local w = vim.fn.expand('<cword>')
            local curl = vfn.getline('.')
            local curc = curl:sub(vfn.col('.'), vfn.col('.'))
            local node = ts_symbol()
            if node and node:type():find('identifier') then
              w = vim.treesitter.get_node_text(node, bufnr)
              log(node:range(), node:type())
            else
              -- log(curc, node:type(), vim.treesitter.get_node_text(node, bufnr))
              -- cursor at end of symbol
              if curc:match('%W') and curc ~= '_' then
                local cur_pos = vim.fn.getpos('.')
                cur_pos[3] = cur_pos[3] - 1
                vfn.setpos('.', cur_pos)
                log('move back')

                node = ts_symbol()
                if node and node:type():find('identifier') then
                  w = vim.treesitter.get_node_text(node, bufnr)
                else
                  w = vim.fn.expand('<cword>')
                end
                cur_pos[3] = cur_pos[3] + 1
                vfn.setpos('.', cur_pos)
              end
            end
            log(curc, w)
            incremental_rename_preview({ args = w, floating = false }, ns, bufnr)
          end,
        })
        vim.keymap.set({ 'i', 'n' }, confirm_key, function()
          print('done rename')
          local input = vim.fn.expand('<cword>')
          log('newname', input)
          state.confirm = true
          vim.cmd('stopinsert')
          on_finish_cb()
        end, { buffer = bufnr })

        if cancel_key == nil or cancel_key == '' then
          vim.api.nvim_create_autocmd({ 'InsertLeave' }, {
            group = rename_group,
            callback = function()
              state.confirm = nil
              on_finish_cb()
            end,
          })
        else
          vim.keymap.set({ 'i', 'n' }, cancel_key, function()
            print('cancel rename')
            state.confirm = nil
            on_finish_cb()
          end, { buffer = bufnr })
        end

        vim.cmd('noautocmd startinsert')
      end, bufnr)
    else
      assert(
        client.supports_method('textDocument/rename'),
        'Client must support textDocument/rename'
      )
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
