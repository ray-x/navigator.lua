local M = {}
local ListView = require "guihua.listview"
local TextView = require "guihua.textview"
local util = require "navigator.util"
local log = require"navigator.util".log
local trace = require"navigator.util".trace
local api = vim.api

local top_center = require"guihua.location".top_center

local path_sep = require"navigator.util".path_sep()
local path_cur = require"navigator.util".path_cur()
function M._preview_location(opts) -- location, width, pos_x, pos_y
  local uri = opts.uri
  if uri == nil then
    log("invalid/nil uri ")
    return
  end
  local bufnr = vim.uri_to_bufnr(uri)
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  --

  local display_range = opts.location.range
  -- if range.start == nil then
  --   print("error invalid range")
  --   return
  -- end
  -- if range.start.line == nil then
  --   range.start.line = range["end"].line - 1
  --   opts.lnum = range["end"].line + 1
  --   log(opts)
  -- end
  -- if range["end"].line == nil then
  --   range["end"].line = range.start.line + 1
  --   opts.lnum = range.start.line + 1
  --   log(opts)
  -- end
  -- TODO: preview height
  -- local contents = api.nvim_buf_get_lines(bufnr, range.start.line, range["end"].line, false)
  --
  local syntax = api.nvim_buf_get_option(bufnr, "ft")
  if syntax == nil or #syntax < 1 then
    syntax = "c"
  end

  -- trace(syntax, contents)
  local win_opts = {
    syntax = syntax,
    width = opts.width,
    height = display_range['end'].line - display_range.start.line + 1,
    preview_height = opts.height or opts.preview_height,
    pos_x = opts.offset_x,
    pos_y = opts.offset_y,
    range = opts.range,
    display_range = display_range,
    uri = uri,
    allow_edit = opts.enable_edit
  }
  -- win_opts.items = contents
  win_opts.hl_line = opts.lnum - display_range.start.line
  if win_opts.hl_line < 0 then
    win_opts.hl_line = 1
  end
  trace(opts.lnum, opts.range.start.line, win_opts.hl_line)
  log(win_opts)
  local w = TextView:new({
    loc = "offset_center",
    rect = {
      height = win_opts.height, -- opts.preview_heigh or 12, -- TODO 12
      width = win_opts.width,
      pos_x = win_opts.pos_x,
      pos_y = win_opts.pos_y
    },
    list_view_height = win_opts.height,
    -- data = display_data,
    relative = win_opts.relative,
    -- data = opts.items, -- either items or uri
    uri = win_opts.uri,
    syntax = win_opts.syntax,
    enter = win_opts.enter or false,
    range = win_opts.range,
    border = opts.border,
    display_range = win_opts.display_range,
    hl_line = win_opts.hl_line,
    allow_edit = win_opts.allow_edit
  })
  return w
end

function M.preview_uri(opts) -- uri, width, line, col, offset_x, offset_y
  local line_beg = opts.lnum - 1
  if line_beg >= 2 then
    line_beg = line_beg - 2
  end
  local loc = {uri = opts.uri, range = {start = {line = line_beg}}}

  -- TODO: preview height
  loc.range["end"] = {line = opts.lnum + opts.preview_height}
  opts.location = loc

  trace("uri", opts.uri, opts.lnum, opts.location.range.start.line, opts.location.range['end'].line)
  return M._preview_location(opts)
end

function M.new_list_view(opts)
  local config = require("navigator").config_values()

  local items = opts.items
  local data = {}

  local wwidth = api.nvim_get_option("columns")

  local loc = "top_center"

  local mwidth = _NgConfigValues.width
  local width = math.floor(wwidth * mwidth)
  if config.width ~= nil and config.width > 0.3 and config.width < 0.99 then
    width = math.floor(wwidth * config.width)
  end
  width = math.min(120, width)
  local wheight = math.floor(1 + api.nvim_get_option("lines")
                                 * (_NgConfigValues.height + _NgConfigValues.preview_height))
  local pheight = math.floor(api.nvim_get_option("lines") * _NgConfigValues.preview_height)
  local prompt = opts.prompt or false
  if opts.rawdata then
    data = items
  else
    trace(items)
    data = require"navigator.render".prepare_for_render(items, opts)
  end

  local border = _NgConfigValues.border or 'shadow'

  if data and not vim.tbl_isempty(data) then
    -- replace
    -- TODO: 10 vimrc opt
    if #data > 10 and opts.prompt == nil then
      loc = "top_center"
      prompt = true
    end

    local lheight = math.min(#data, math.floor(wheight * _NgConfigValues.height))

    local r, _ = top_center(lheight, width)

    local offset_y = r + lheight
    -- style shadow took 1 lines
    if border ~= 'none' then
      if border == 'shadow' then
        offset_y = offset_y + 1
      else
        offset_y = offset_y + 1 -- single?
      end
    end
    -- if border is not set, this should be r+lheigh
    if prompt then
      offset_y = offset_y + 1 -- need to check this out
    end
    local idx = require"guihua.util".fzy_idx
    local transparency = _NgConfigValues.transparency
    if transparency == 100 then
      transparency = nil
    end
    return ListView:new({
      loc = loc,
      prompt = prompt,
      relative = opts.relative,
      style = opts.style,
      api = opts.api,
      rect = {height = lheight, width = width, pos_x = 0, pos_y = 0},
      -- preview_height = pheight,
      ft = opts.ft or 'guihua',
      -- data = display_data,
      data = data,
      border = border,
      on_confirm = opts.on_confirm or function(item)
        if item.filename ~= nil then
          log("openfile ", item.filename, item.lnum, item.col)
          util.open_file_at(item.filename, item.lnum, item.col)
        end
      end,
      transparency = transparency,
      on_move = opts.on_move or function(item)
        trace("on move", pos, item)
        trace("on move", pos, item.text or item, item.uri, item.filename)
        -- todo fix
        if item.uri == nil then
          item.uri = "file:///" .. item.filename
        end
        return M.preview_uri({
          uri = item.uri,
          width = width,
          height = lheight, -- this is to cal offset
          preview_height = pheight,
          lnum = item.lnum,
          col = item.col,
          range = item.range,
          offset_x = 0,
          offset_y = offset_y,
          border = border,
          enable_edit = opts.enable_preview_edit or false
        })
      end
    })
  end
end

return M

-- Doc

--[[
    -- each item should look like this
    -- update if API changes
    {
      call_by = { <table 1> },
      col = 40,
      display_filename = "./curry.js",
      filename = "/Users/username/lsp_test/js/curry.js",
      lnum = 4,
      range = {
        end = {
          character = 46,
          line = 3  -- note: C index
        },
        start = {
          character = 39,
          line = 3
        }
      },
      rpath = "js/curry.js",
      text = "      (sum, element, index) => (sum += element * vector2[index]),",
      uri = "file:///Users/username/lsp_test/js/curry.js"
    }
  --]]

-- on move item:
--[[

 call_by = { {
      kind = " ",
      node_scope = {
        end = {
          character = 1,
          line = 7
        },
        start = {
          character = 0,
          line = 0
        }
      },
      node_text = "curriedDot",
      type = "var"
    } },
  col = 22,
  display_filename = "./curry.js",
  filename = "/Users/username/lsp_test/js/curry.js",
  lnum = 4,
  range = {
    end = {
      character = 26,
      line = 3
    },
    start = {
      character = 21,
      line = 3
    }
  },
  rpath = "js/curry.js",
  text = "    4:        (sum, element, index) => (sum += element * vector     curriedDot()",
  uri = "file:///Users/username/lsp_test/js/curry.js"
--
]]
