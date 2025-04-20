local lsp = vim.lsp
local util = lsp.util
local nutils = require('navigator.util')
local lsphelper = require('navigator.lspwrapper')
local api = vim.api
local log = nutils.log
local M = {}

local function handler(err, result, ctx, config)
  config = config or {}
  config.focus_id = ctx.method
  if api.nvim_get_current_buf() ~= ctx.bufnr then
    -- Ignore result since buffer changed. This happens for slow language servers.
    return
  end
  local failed = false
  if err then
    vim.notify('no hover info ' .. vim.inspect(err))
    failed = true
  end
  if not result or not result.contents then
    if config.silent ~= true then
      vim.notify('No hover information available')
    end
    failed = true
  end
  if failed then
    if _NgConfigValues.lsp.hover.ft then
      local fallback_fn = _NgConfigValues.hover.ft or ''
      if type(fallback_fn) == 'function' then
        fallback_fn(ctx, config)
      end
    end
    return -- return early as no valid hover info lets fallback to other sources
  end

  local format = 'markdown'
  local contents ---@type string[]
  if type(result.contents) == 'table' and result.contents.kind == 'plaintext' then
    format = 'plaintext'
    contents = vim.split(result.contents.value or '', '\n', { trimempty = true })
  else
    contents = util.convert_input_to_markdown_lines(result.contents)
  end
  if vim.tbl_isempty(contents) then
    if config.silent ~= true then
      vim.notify('No information available')
    end
    return
  end

  local double = { '╔', '═', '╗', '║', '╝', '═', '╚', '║' }
  local single = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' }

  local border_style = single
  if _NgConfigValues.border == 'double' then
    border_style = double
  end
  config.border = border_style

  return util.open_floating_preview(contents, format, config)
end

function M.hover(opts)
  if not lsphelper.check_capabilities('hoverProvider') then
    return
  end

  opts = {}
  opts.bufnr = api.nvim_get_current_buf()

  local params = nutils.make_position_params()
  log('hover params', params)

  lsphelper.call_sync_single(
    'textDocument/hover',
    params,
    opts,
    handler
  )
end

return M
