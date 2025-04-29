local lsp = vim.lsp
local util = lsp.util
local nutils = require('navigator.util')
local api = vim.api
local log = nutils.log
local M = {}

local hover_ns = api.nvim_create_namespace('nvim.lsp.hover_range')
local ms = lsp.protocol.Methods


--- @class vim.lsp.buf.hover.Opts : vim.lsp.util.open_floating_preview.Opts
--- @field silent? boolean

--- Displays hover information about the symbol under the cursor in a floating
--- window. The window will be dismissed on cursor move.
--- Calling the function twice will jump into the floating window
--- (thus by default, "KK" will open the hover window and focus it).
--- In the floating window, all commands and mappings are available as usual,
--- except that "q" dismisses the window.
--- You can scroll the contents the same as you would any other buffer.
---
--- Note: to disable hover highlights, add the following to your config:
---
--- ```lua
--- vim.api.nvim_create_autocmd('ColorScheme', {
---   callback = function()
---     vim.api.nvim_set_hl(0, 'LspReferenceTarget', {})
---   end,
--- })
--- ```
--- @param config? vim.lsp.buf.hover.Opts
function M.hover(config)
  config = config or {}
  config.focus_id = ms.textDocument_hover

  lsp.buf_request_all(0, ms.textDocument_hover, client_positional_params(), function(results, ctx)
    local bufnr = assert(ctx.bufnr)
    if api.nvim_get_current_buf() ~= bufnr then
      -- Ignore result since buffer changed. This happens for slow language servers.
      return
    end

    -- Filter errors from results
    local results1 = {} --- @type table<integer,lsp.Hover>

    for client_id, resp in pairs(results) do
      local err, result = resp.err, resp.result
      if err then
        lsp.log.error(err.code, err.message)
      elseif result then
        results1[client_id] = result
      end
    end

    if vim.tbl_isempty(results1) then
      if config.silent ~= true then
        vim.notify('No information available')
      end
      return
    end

    local contents = {} --- @type string[]

    local nresults = #vim.tbl_keys(results1)

    local format = 'markdown'

    for client_id, result in pairs(results1) do
      local client = assert(lsp.get_client_by_id(client_id))
      if nresults > 1 then
        -- Show client name if there are multiple clients
        contents[#contents + 1] = string.format('# %s', client.name)
      end
      if type(result.contents) == 'table' and result.contents.kind == 'plaintext' then
        if #results1 == 1 then
          format = 'plaintext'
          contents = vim.split(result.contents.value or '', '\n', { trimempty = true })
        else
          -- Surround plaintext with ``` to get correct formatting
          contents[#contents + 1] = '```'
          vim.list_extend(
            contents,
            vim.split(result.contents.value or '', '\n', { trimempty = true })
          )
          contents[#contents + 1] = '```'
        end
      else
        vim.list_extend(contents, util.convert_input_to_markdown_lines(result.contents))
      end
      local range = result.range
      if range then
        local start = range.start
        local end_ = range['end']
        local start_idx = util._get_line_byte_from_position(bufnr, start, client.offset_encoding)
        local end_idx = util._get_line_byte_from_position(bufnr, end_, client.offset_encoding)

        vim.hl.range(
          bufnr,
          hover_ns,
          'LspReferenceTarget',
          { start.line, start_idx },
          { end_.line, end_idx },
          { priority = vim.hl.priorities.user }
        )
      end
      contents[#contents + 1] = '---'
    end

    -- Remove last linebreak ('---')
    contents[#contents] = nil

    if vim.tbl_isempty(contents) then
      if config.silent ~= true then
        vim.notify('No information available')
      end
      return
    end

    local _, winid = lsp.util.open_floating_preview(contents, format, config)

    api.nvim_create_autocmd('WinClosed', {
      pattern = tostring(winid),
      once = true,
      callback = function()
        api.nvim_buf_clear_namespace(bufnr, hover_ns, 0, -1)
        return true
      end,
    })
    --
  end)
end
