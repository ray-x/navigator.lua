local log = require('vim.lsp.log')
local util = require('vim.lsp.util')
local api = vim.api
local bufstates = {}
return {
  on_inlayhint = function(err, result, ctx, _)
    if err then
      if log.error() then
        log.error('inlayhint', err)
      end
      return
    end
    local bufnr = assert(ctx.bufnr)
    if util.buf_versions[bufnr] ~= ctx.version then
      return
    end
    local client_id = ctx.client_id
    if not result then
      return
    end
    local bufstate = bufstates[bufnr]
    if not bufstate or not bufstate.enabled then
      return
    end
    if not (bufstate.client_hint and bufstate.version) then
      bufstate.client_hint = vim.defaulttable()
      bufstate.version = ctx.version
    end
    local hints_by_client = bufstate.client_hint
    local client = assert(vim.lsp.get_client_by_id(client_id))

    local new_hints_by_lnum = vim.defaulttable()
    local num_unprocessed = #result
    if num_unprocessed == 0 then
      hints_by_client[client_id] = {}
      bufstate.version = ctx.version
      api.nvim__buf_redraw_range(bufnr, 0, -1)
      return
    end

    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    ---@param position lsp.Position
    ---@return integer
    local function pos_to_byte(position)
      local col = position.character
      if col > 0 then
        local line = lines[position.line + 1] or ''
        local ok, convert_result
        ok, convert_result = pcall(util._str_byteindex_enc, line, col, client.offset_encoding)
        if ok then
          return convert_result
        end
        return math.min(#line, col)
      end
      return col
    end

    for _, hint in ipairs(result) do
      local lnum = hint.position.line
      hint.position.character = pos_to_byte(hint.position)
      table.insert(new_hints_by_lnum[lnum], hint)
    end

    hints_by_client[client_id] = new_hints_by_lnum
    bufstate.version = ctx.version
    api.nvim__buf_redraw_range(bufnr, 0, -1)
  end,
}
