local M = {}
local ListView = require "guihua.listview"
local TextView = require "guihua.textview"
local View = require "guihua.view"
local util = require "navigator.util"
local log = require "navigator.util".log
local verbose = require "navigator.util".verbose

function M.new_preview(opts)
  return TextView:new(
    {
      loc = "top_center",
      rect = {
        height = #opts.items + 4,
        width = opts.width or 90,
        pos_x = opts.pos_x or 0,
        pos_y = opts.pos_y or 4
      },
      -- data = display_data,
      relative = opts.relative,
      data = opts.items,
      syntax = opts.syntax,
      enter = opts.enter or false
    }
  )
end

function M._preview_location(location, width, pos_x, pos_y)
  local api = vim.api
  local uri = location.targetUri or location.uri
  if uri == nil then
    log("invalid uri ", location)
    return
  end
  local bufnr = vim.uri_to_bufnr(uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  --
  local range = location.targetRange or location.range
  local contents = api.nvim_buf_get_lines(bufnr, range.start.line, range["end"].line + 1, false)
  --
  local syntax = api.nvim_buf_get_option(bufnr, "syntax")
  if syntax == nil or #syntax < 1 then
    syntax = api.nvim_buf_get_option(bufnr, "ft")
  end

  verbose(syntax, contents)
  local opts = {syntax = syntax, width = width, pos_x = pos_x or 0, pos_y = pos_y or 10}
  opts.items = contents
  return M.new_preview(opts)
end

--   local bufnr, winnr =lsp.util.open_floating_preview(contents, syntax, {offset_x=30, offset_y=20})
--
--   vim.api.nvim_buf_set_var(bufnr, "lsp_floating", true)
--   return bufnr, winnr
--

function M.preview_file(filename, width, line, col, offset_x, offset_y)
  verbose("file", filename, line, offset_x, offset_y)
  if line >= 2 then
    line = line - 2
  end
  local loc = {uri = "file:///" .. filename, targetRange = {start = {line = line}}}
  offset_x = offset_x or 0
  offset_y = offset_y or 6
  loc.targetRange["end"] = {line = line + 4}
  return M._preview_location(loc, width, offset_x, offset_y)
end

function M.preview_uri(uri, width, line, col, offset_x, offset_y)
  verbose("uri", uri, line, offset_x, offset_y)
  if line >= 2 then
    line = line - 2
  end
  offset_x = offset_x or 0
  offset_y = offset_y or 6
  local loc = {uri = uri, targetRange = {start = {line = line}}}
  loc.targetRange["end"] = {line = line + 4}
  return M._preview_location(loc, width, offset_x, offset_y)
end

function M.new_list_view(opts)
  local items = opts.items
  local data = {}
  if opts.rawdata then
    data = items
  else
    data = require "guihua.util".aggregate_filename(items, opts)
  end
  local wwidth = vim.api.nvim_get_option("columns")
  local width = opts.width or math.floor(wwidth * 0.8)
  local wheight = math.floor(vim.api.nvim_get_option("lines") * 0.8)
  local prompt = opts.prompt or false
  if data and not vim.tbl_isempty(data) then
    -- replace
    if #data > 10 and opts.prompt == nil then
      prompt = true
    end

    local height = math.min(#data, math.floor(wheight / 2))
    local offset_y = height
    if prompt then
      offset_y = offset_y + 1
    end
    return ListView:new(
      {
        loc = "top_center",
        prompt = prompt,
        relative = opts.relative,
        style = opts.style,
        api = opts.api,
        rect = {
          height = height,
          width = width,
          pos_x = 0,
          pos_y = 0
        },
        -- data = display_data,
        data = data,
        on_confirm = opts.on_confirm or function(pos)
            if pos == 0 then
              pos = 1
            end
            local l = data[pos]
            if l.filename ~= nil then
              util.open_file_at(l.filename, l.lnum)
            end
          end,
        on_move = opts.on_move or function(pos)
            if pos == 0 then
              pos = 1
            end
            local l = data[pos]
            verbose("on move", pos, l.text or l, l.uri, l.filename)
            -- todo fix
            if l.uri ~= nil then
              return M.preview_uri(l.uri, width, l.lnum, l.col, 0, offset_y)
            else
              return M.preview_file(l.filename, width, l.lnum, l.col, 0, offset_y)
            end
          end
      }
    )
  end
end

return M
