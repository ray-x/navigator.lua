local gui = require "navigator.gui"
local M = {}
local log = require "navigator.util".log
local lsphelper = require "navigator.lspwrapper"
local locations_to_items = lsphelper.locations_to_items

function M.document_symbols(opts)
  opts = opts or {}
  local params = vim.lsp.util.make_position_params()
  params.context = {includeDeclaration = true}
  params.query = ""
  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, opts.timeout or 10000)
  local locations = {}
  log(results_lsp)
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result) or {})
    end
  end
  local lines = {}

  for _, loc in ipairs(locations) do
    table.insert(lines, string.format("%s:%s:%s", loc.filename, loc.lnum, loc.text))
  end
  local cmd = table.concat(lines, "\n")
  if #lines > 0 then
    gui.new_list_view({data = lines})
  else
    print("symbols not found")
  end
end

function M.workspace_symbols(opts)
  opts = opts or {}
  local params = vim.lsp.util.make_position_params()
  params.context = {includeDeclaration = true}
  params.query = ""
  local results_lsp = vim.lsp.buf_request_sync(0, "workspace/symbol", params, opts.timeout or 10000)

  log(results_lsp)
  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result) or {})
    end
  end
  local lines = {}

  for _, loc in ipairs(locations) do
    table.insert(lines, string.format("%s:%s:%s", loc.filename, loc.lnum, loc.text))
  end
  if #lines > 0 then
    gui.new_list_view({data = lines})
  else
    print("symbols not found")
  end
end

function M.symbol_handler(_, _, result, _, bufnr)
  if not result or vim.tbl_isempty(result) then
    print("symbol not found")
    return
  end
  -- log(result)
  local locations = {}
  for i = 1, #result do
    local item = result[i].location
    item.kind = result[i].kind
    item.containerName = result[i].containerName
    item.name = result[i].name
    item.text = result[i].name
    if #item.containerName > 0 then
      item.text = item.text:gsub(item.containerName, '', 1)
    end
    table.insert(locations, item)
  end
  local items = locations_to_items(locations)
  gui.new_list_view({items = items, prompt = true})

  -- if locations == nil or vim.tbl_isempty(locations) then
  --   print "References not found"
  --   return
  -- end
  -- local items = locations_to_items(locations)
  -- gui.new_list_view({items = items})
  -- local filename = vim.api.nvim_buf_get_name(bufnr)
  -- local  items = vim.lsp.util.symbols_to_items(result, bufnr)
  -- local data = {}
  -- for i, item in pairs(action.items) do
  --   data[i] = item.text
  --   if filename ~= item.filename then
  --     local cwd = vim.fn.getcwd(0) .. "/"
  --     local add = util.get_relative_path(cwd, item.filename)
  --     data[i] = data[i] .. " - " .. add
  --   end
  --   item.text = nil
  -- end
  -- opts.data = data
  -- action.popup = popfix:new(opts)
  -- if not action.popup then
  --   action.items = nil
  -- end
  -- if action.popup.list then
  --   util.setFiletype(action.popup.list.buffer, "lsputil_symbols_list")
  -- end
  -- if action.popup.preview then
  --   util.setFiletype(action.popup.preview.buffer, "lsputil_symbols_preview")
  -- end
  -- if action.popup.prompt then
  --   util.setFiletype(action.popup.prompt.buffer, "lsputil_symbols_prompt")
  -- end
  -- opts.data = nil
end

return M
