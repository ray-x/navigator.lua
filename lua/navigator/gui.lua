local M = {}
local ListView = require "guihua.listview"
local TextView = require "guihua.textview"
local View = require "guihua.view"
local util = require "navigator.util"
local log = require "navigator.util".log
local verbose = require "navigator.util".verbose
local api = vim.api

function M.new_preview(opts)
  return TextView:new(
    {
      loc = "top_center",
      rect = {
        height = opts.preview_heigh or 12,
        width = opts.width or 100,
        pos_x = opts.pos_x or 0,
        pos_y = opts.pos_y or 4
      },
      -- data = display_data,
      relative = opts.relative,
      data = opts.items,
      syntax = opts.syntax,
      enter = opts.enter or false,
      hl_line = opts.hl_line
    }
  )
end

function M._preview_location(opts) --location, width, pos_x, pos_y
  local uri = opts.location.targetUri or opts.location.uri
  if opts.uri == nil then
    log("invalid/nil uri ")
    return
  end
  local bufnr = vim.uri_to_bufnr(uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  --

  local range = opts.location.targetRange or opts.location.range
  local contents = api.nvim_buf_get_lines(bufnr, range.start.line, range["end"].line + 10, false)

  --
  local syntax = api.nvim_buf_get_option(bufnr, "syntax")
  if syntax == nil or #syntax < 1 then
    syntax = api.nvim_buf_get_option(bufnr, "ft")
  end

  verbose(syntax, contents)
  local win_opts = {syntax = syntax, width = opts.width, pos_x = opts.offset_x or 0, pos_y = opts.offset_y or 10}
  win_opts.items = contents
  win_opts.hl_line = opts.lnum - range.start.line
  local w = M.new_preview(win_opts)

  return w
end

function M.preview_uri(opts) -- uri, width, line, col, offset_x, offset_y
  verbose("uri", opts.uri, opts.lnum, opts.offset_x, opts.offset_y)
  local line_beg = opts.line
  if opts.lnum >= 2 then
    line_beg = opts.lnum - 2
  end
  local loc = {uri = opts.uri, targetRange = {start = {line = line_beg}}}
  -- TODO: options for 8
  loc.targetRange["end"] = {line = opts.lnum + 8}
  opts.location = loc
  return M._preview_location(opts)
end

function M.new_list_view(opts)
  local items = opts.items
  local data = {}
  if opts.rawdata then
    data = items
  else
    data = require "guihua.util".aggregate_filename(items, opts)
  end
  local wwidth = api.nvim_get_option("columns")
  local width = opts.width or math.floor(wwidth * 0.8)
  local wheight = math.floor(api.nvim_get_option("lines") * 0.8)
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
        on_move = opts.on_move or
          function(pos)
            if pos == 0 then
              pos = 1
            end
            local l = data[pos]
            verbose("on move", pos, l.text or l, l.uri, l.filename)
            -- todo fix
            if l.uri == nil then
              l.uri = "file:///" .. l.filename
            end
              return M.preview_uri(
                {uri = l.uri, width = width, lnum = l.lnum, col = l.col, offsetx = 0, offset_y = offset_y}
              )
          end
      }
    )
  end
end

return M
