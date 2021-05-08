local util = require "navigator.util"
local log = util.log
local api = vim.api
local references = {}

-- returns r1 < r2 based on start of range
local function before(r1, r2)
  if r1.start.line < r2.start.line then
    return true
  end
  if r2.start.line < r1.start.line then
    return false
  end
  if r1.start.character < r2.start.character then
    return true
  end
  return false
end

local function handle_document_highlight(_, _, result, _, bufnr, _)
  if not bufnr then
    return
  end
  if type(result) ~= "table" then
    vim.lsp.util.buf_clear_references(bufnr)
    return
  end

  table.sort(
    result,
    function(a, b)
      return before(a.range, b.range)
    end
  )
  references[bufnr] = result
end
-- modify from vim-illuminate
local function goto_adjent_reference(opt)
  log(opt)
  opt = vim.tbl_extend("force", {forward = true, wrap = true}, opt or {})

  local bufnr = vim.api.nvim_get_current_buf()
  local refs = references[bufnr]
  if not refs or #refs == 0 then
    return nil
  end

  local next = nil
  local nexti = nil
  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
  local crange = {start = {line = crow - 1, character = ccol}}

  for i, ref in ipairs(refs) do
    local range = ref.range
    if opt.forward then
      if before(crange, range) and (not next or before(range, next)) then
        next = range
        nexti = i
      end
    else
      if before(range, crange) and (not next or before(next, range)) then
        next = range
        nexti = i
      end
      log(nexti, next)
    end
  end
  if not next and opt.wrap then
    nexti = opt.reverse and #refs or 1
    next = refs[nexti].range
  end

  log(next)
  vim.api.nvim_win_set_cursor(0, {next.start.line + 1, next.start.character})
  return next
end

local function documentHighlight()
  api.nvim_exec(
    [[
      hi LspReferenceRead cterm=bold gui=Bold ctermbg=yellow guibg=purple4
      hi LspReferenceText cterm=bold gui=Bold ctermbg=red guibg=gray27
      hi LspReferenceWrite cterm=bold gui=Bold,Italic ctermbg=red guibg=MistyRose
      augroup lsp_document_highlight
        autocmd! * <buffer>
        autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
        autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
      augroup END
    ]],
    false
  )
  vim.lsp.handlers["textDocument/documentHighlight"] = function(_, _, result, _, bufnr)
    if not result then
      return
    end
    bufnr = api.nvim_get_current_buf()
    vim.lsp.util.buf_clear_references(bufnr)
    vim.lsp.util.buf_highlight_references(bufnr, result)
    bufnr = bufnr or 0
    if type(result) ~= "table" then
      vim.lsp.util.buf_clear_references(bufnr)
      return
    end
    table.sort(
      result,
      function(a, b)
        return before(a.range, b.range)
      end
    )
    references[bufnr] = result
  end
end

return {
  documentHighlight = documentHighlight,
  goto_adjent_reference = goto_adjent_reference,
  handle_document_highlight = handle_document_highlight
}
