local M = {}
local ListView = require('guihua.listview')
local TextView = require('guihua.textview')
local util = require('navigator.util')
local log = require('navigator.util').log
local trace = require('navigator.util').trace
local api = vim.api

local top_center = require('guihua.location').top_center

local path_sep = require('navigator.util').path_sep()
local path_cur = require('navigator.util').path_cur()
function M.new_list_view(opts)
  log(opts)

  local config = require('navigator').config_values()

  local items = opts.items
  local data = {}

  local wwidth = api.nvim_get_option('columns')

  local loc = 'top_center'

  opts.min_width = opts.min_width or 0.3
  opts.min_height = opts.min_height or 0.3

  opts.height_ratio = config.height
  opts.width_ratio = config.width
  opts.preview_height_ratio = _NgConfigValues.preview_height or 0.3
  opts.preview_lines = _NgConfigValues.preview_lines
  if opts.rawdata then
    opts.data = items
  else
    opts.data = require('navigator.render').prepare_for_render(items, opts)
  end
  opts.border = _NgConfigValues.border or 'shadow'
  opts.rect = { height = lheight, width = width, pos_x = 0, pos_y = 0 }
  if not items or vim.tbl_isempty(items) then
    log('empty data return')
    return
  end

  opts.transparency = _NgConfigValues.transparency
  opts.external = _NgConfigValues.external
  opts.preview_lines_before = 3
  log(opts)
  return require('guihua.gui').new_list_view(opts)
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

-- function M._preview_location(opts) -- location, width, pos_x, pos_y
--   local uri = opts.uri
--   if uri == nil then
--     log('invalid/nil uri ')
--     return
--   end
--   local bufnr = vim.uri_to_bufnr(uri)
--   if not api.nvim_buf_is_loaded(bufnr) then
--     vim.fn.bufload(bufnr)
--   end
--   --
--
--   local display_range = opts.location.range
--   -- if range.start == nil then
--   --   print("error invalid range")
--   --   return
--   -- end
--   -- if range.start.line == nil then
--   --   range.start.line = range["end"].line - 1
--   --   opts.lnum = range["end"].line + 1
--   --   log(opts)
--   -- end
--   -- if range["end"].line == nil then
--   --   range["end"].line = range.start.line + 1
--   --   opts.lnum = range.start.line + 1
--   --   log(opts)
--   -- end
--   -- TODO: preview height
--   -- local contents = api.nvim_buf_get_lines(bufnr, range.start.line, range["end"].line, false)
--   --
--   local syntax = api.nvim_buf_get_option(bufnr, 'ft')
--   if syntax == nil or #syntax < 1 then
--     syntax = 'c'
--   end
--
--   -- trace(syntax, contents)
--   local win_opts = {
--     syntax = syntax,
--     width = opts.width,
--     height = display_range['end'].line - display_range.start.line + 1,
--     preview_height = opts.height or opts.preview_height,
--     pos_x = opts.offset_x,
--     pos_y = opts.offset_y,
--     range = opts.range,
--     display_range = display_range,
--     uri = uri,
--     allow_edit = opts.enable_edit,
--   }
--
--   if _NgConfigValues.external then
--     win_opts.external = true
--     win_opts.relative = nil
--   end
--   -- win_opts.items = contents
--   win_opts.hl_line = opts.lnum - display_range.start.line
--   if win_opts.hl_line < 0 then
--     win_opts.hl_line = 1
--   end
--   trace(opts.lnum, opts.range.start.line, win_opts.hl_line)
--   log(win_opts)
--   local w = TextView:new({
--     loc = 'offset_center',
--     rect = {
--       height = win_opts.height, -- opts.preview_heigh or 12, -- TODO 12
--       width = win_opts.width,
--       pos_x = win_opts.pos_x,
--       pos_y = win_opts.pos_y,
--     },
--     list_view_height = win_opts.height,
--     -- data = display_data,
--     relative = win_opts.relative,
--     -- data = opts.items, -- either items or uri
--     uri = win_opts.uri,
--     syntax = win_opts.syntax,
--     enter = win_opts.enter or false,
--     range = win_opts.range,
--     border = opts.border,
--     display_range = win_opts.display_range,
--     hl_line = win_opts.hl_line,
--     allow_edit = win_opts.allow_edit,
--     external = win_opts.external,
--   })
--   return w
-- end

-- function M.preview_uri(opts) -- uri, width, line, col, offset_x, offset_y
--   -- local handle = vim.loop.new_async(vim.schedule_wrap(function()
--   local line_beg = opts.lnum or 2 - 1
--   if line_beg >= opts.preview_lines_before or 1 then
--     line_beg = line_beg - opts.preview_lines_before or 1
--   elseif line_beg >= 2 then
--     line_beg = line_beg - 2
--   end
--   local loc = { uri = opts.uri, range = { start = { line = line_beg } } }
--
--   -- TODO: preview height
--   loc.range['end'] = { line = opts.lnum + opts.preview_height }
--   opts.location = loc
--
--   trace('uri', opts.uri, opts.lnum, opts.location.range.start.line, opts.location.range['end'].line)
--   return M._preview_location(opts)
-- end
