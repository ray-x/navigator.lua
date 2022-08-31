local util = require('navigator.util')
local log = util.log
local trace = util.trace
local clone = require('guihua.util').clone

local M = {}
local function filename(url)
  if url == nil then
    return ''
  end
  return url:match('^.+/(.+)$') or url
end

local function extension(url)
  local ext = url:match('^.+(%..+)$') or 'txt'
  return string.sub(ext, 2)
end

local function get_pads(win_width, text, postfix)
  local trim = false
  local margin = win_width - #text - #postfix
  if margin < 0 then
    trace('line too long', win_width, #text, #postfix)
    if #postfix > 1 then
      trim = true
    end
  end
  local sz = #text
  if sz < 30 then
    sz = 30
  end
  local space
  local i = math.floor((sz + 10) / 10)
  i = i * 10 - #text
  trace(i, #text, #postfix, postfix, text, win_width)
  if i + #text + #postfix < win_width then
    local rem = win_width - i - #text - #postfix
    rem = math.floor(rem / 10)
    if rem > 0 then
      i = i + rem * 10
      -- log(i)
    end
  end

  if i > 3 then
    i = i - 3
  end
  space = string.rep(' ', i)
  trace(text, i, postfix, win_width)
  return space, trim
end

function M.prepare_for_render(items, opts)
  opts = opts or {}
  if items == nil or #items < 1 then
    vim.notify('no item found or empty fields', vim.lsp.log_levels.INFO)
    return
  end
  local item = clone(items[1])
  local display_items = { item }
  local last_summary_idx = 1
  local total_ref_in_file = 1
  local total = opts.total
  local icon = ' '
  local lspapi = opts.api or '∑'

  local ok, devicons = pcall(require, 'nvim-web-devicons')
  if ok then
    local fn = filename(items[1].filename)
    local ext = extension(fn)
    icon = devicons.get_icon(fn, ext) or icon
  end
  -- local call_by_presented = false
  opts.width = opts.width or math.floor(vim.api.nvim_get_option('columns') * 0.8)
  local win_width = opts.width -- buf

  for i = 1, #items do
    local space
    local trim
    local lspapi_display = lspapi
    items[i].symbol_name = items[i].symbol_name or '' -- some LSP API does not have range for this

    local fn = display_items[last_summary_idx].filename
    local dfn = items[i].display_filename
    if last_summary_idx == 1 then
      lspapi_display = items[i].symbol_name .. ' ' .. lspapi_display

      trace(items[1], lspapi_display, display_items[last_summary_idx])
    end

    display_items[last_summary_idx].filename_only = true
    -- trace(items[i], items[i].filename, last_summary_idx, display_items[last_summary_idx].filename)
    -- TODO refact display_filename generate part
    if items[i].filename == fn or opts.hide_filename then
      space, trim = get_pads(opts.width, icon .. ' ' .. dfn, lspapi_display .. ' 14 of 33 ')
      if trim and opts.width > 50 and #dfn > opts.width - 20 then
        local fn1 = string.sub(dfn, 1, opts.width - 50)
        local fn2 = string.sub(dfn, #dfn - 10, #dfn)
        display_items[last_summary_idx].display_filename = fn1 .. '' .. fn2
        space = '  '
        -- log("trim", fn1, fn2)
      end
      local api_disp = string.format(
        '%s  %s%s%s %i',
        icon,
        display_items[last_summary_idx].display_filename,
        space,
        lspapi_display,
        total_ref_in_file
      )

      if total then
        api_disp = api_disp .. ' of: ' .. tostring(total)
      end

      display_items[last_summary_idx].text = api_disp
      total_ref_in_file = total_ref_in_file + 1
    else
      lspapi_display = lspapi
      item = clone(items[i])

      space, trim = get_pads(opts.width, icon .. '  ' .. item.display_filename, lspapi_display .. ' 12 of 33')
      if trim and opts.width > 52 and #item.display_filename > opts.width - 20 then
        item.display_filename = string.sub(item.display_filename, 1, opts.width - 52)
          .. ''
          .. string.sub(item.display_filename, #item.display_filename - 10, #item.display_filename)
        space = '  '
      end
      item.text = string.format('%s  %s%s%s 1', icon, item.display_filename, space, lspapi_display)

      trace(item.text)
      table.insert(display_items, item)
      total_ref_in_file = 1
      last_summary_idx = #display_items
    end
    -- content of code lines
    item = clone(items[i])
    item.text = require('navigator.util').trim_and_pad(item.text)
    item.text = string.format('%4i: %s', item.lnum, item.text)
    local ts_report = ''
    if item.lhs then
      ts_report = _NgConfigValues.icons.value_changed
    end

    -- log(item.text, item.symbol_name, item.uri)
    -- log(item.text)
    if item.definition then
      log('definition', item)
      ts_report = ts_report .. _NgConfigValues.icons.value_definition .. ' '
    end
    local header_len = #ts_report + 4 -- magic number 2
    trace(ts_report, header_len)

    item.text = item.text:gsub('%s*[%[%(%{]*%s*$', '')
    if item.call_by ~= nil and item.call_by ~= '' then
      ts_report = ts_report .. ' ' .. item.call_by
    end
    if #ts_report > 1 then
      space, trim = get_pads(win_width, item.text, ts_report)

      local l = math.max(20, opts.width - math.min(20, #ts_report))
      if trim and #item.text < l then
        trim = false
      end
      if trim then
        item.text = string.sub(item.text, 1, l)
        item.text = util.sub_match(item.text)
        -- let check if there are unmatched "/'
      end
      if #space + #item.text + #ts_report >= win_width then
        if #item.text + #ts_report >= win_width then
          space = '  '
          local len = math.max(win_width - #item.text - 4, 16)

          trace('exceeding', #item.text, #ts_report, win_width, len)
          ts_report = ts_report:sub(1, len)
        else
          local remain = win_width - #item.text - #ts_report
          trace('remain', remain)
          space = string.rep(' ', remain)
        end
      end
      item.text = item.text .. space .. ts_report
    end
    local tail = display_items[#display_items].text
    if tail ~= item.text then -- deduplicate
      trace(item.text)
      trace(item.call_by)
      table.insert(display_items, item)
    end
  end

  display_items[last_summary_idx].filename_only = true
  -- display_items[last_summary_idx].text=string.format("%s [%i]", display_items[last_summary_idx].filename,
  -- total_ref_in_file)
  return display_items
end

return M
