local lsp = vim.lsp
local util = lsp.util
local M = {}
function M.handler(_, result, ctx, config)
  config = config or {}
  config.focus_id = ctx.method
  if not (result and result.contents) then
    vim.notify('No information available')
    return
  end
  local markdown_lines = util.convert_input_to_markdown_lines(result.contents)
  markdown_lines = util.trim_empty_lines(markdown_lines)
  if vim.tbl_isempty(markdown_lines) then
    vim.notify('No information available')
    return
  end

  local opts = {}
  opts.wrap = true -- wrapping by default
  opts.stylize_markdown = true
  opts.focus = true

  local contents = lsp.util._trim(markdown_lines, opts)

  -- applies the syntax and sets the lines to the buffer
  local bufnr, winnr = util.open_floating_preview(markdown_lines, 'markdown', config)

  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  contents = lsp.util.stylize_markdown(bufnr, contents, opts)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  return bufnr, winnr
end

return M
