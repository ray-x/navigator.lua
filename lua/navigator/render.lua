local log = require"guihua.log".info
local trace = require"guihua.log".trace
local M = {}
local clone = require'guihua.util'.clone
local function filename(url)
  return url:match("^.+/(.+)$") or url
end

local function extension(url)
  local ext = url:match("^.+(%..+)$") or "txt"
  return string.sub(ext, 2)
end

local function get_pads(win_width, text, postfix)
  local margin = win_width - #text - #postfix
  if margin < 0 then
    if #postfix > 1 then
      text = text:sub(1, #text - 20)
    end
  end
  local sz = #text
  if sz < 30 then
    sz = 30
  end
  local space = ''
  local i = math.floor((sz + 10) / 10)
  i = i * 10 - #text
  space = string.rep(' ', i)
  trace(text, i, postfix, win_width)
  return space
end

function M.prepare_for_render(items, opts)
  opts = opts or {}
  if items == nil or #items < 1 then
    print("no item found or empty fields")
    return
  end
  local item = clone(items[1])
  local display_items = {item}
  local last_summary_idx = 1
  local total_ref_in_file = 1
  local icon = " "
  local lspapi = opts.api or "∑"

  local ok, devicons = pcall(require, "nvim-web-devicons")
  if ok then
    local fn = filename(items[1].filename)
    local ext = extension(fn)
    icon = devicons.get_icon(fn, ext) or icon
  end
  local call_by_presented = false

  opts.width = opts.width or 100
  local win_width = opts.width - 2 -- buf

  for i = 1, #items do
    if items[i].call_by and #items[i].call_by > 0 then
      call_by_presented = true
    end
  end

  for i = 1, #items do
    local space = ''
    local lspapi_display = lspapi
    items[i].symbol_name = items[i].symbol_name or "" -- some LSP API does not have range for this
    if last_summary_idx == 1 then
      lspapi_display = items[i].symbol_name .. ' ' .. lspapi_display
      trace(items[1], lspapi_display)
    end

    -- trace(items[i], items[i].filename, last_summary_idx, display_items[last_summary_idx].filename)
    if items[i].filename == display_items[last_summary_idx].filename then
      space = get_pads(opts.width, icon .. ' ' .. display_items[last_summary_idx].display_filename,
                       lspapi_display .. ' 12')
      display_items[last_summary_idx].text = string.format("%s  %s%s%s %i", icon,
                                                           display_items[last_summary_idx]
                                                               .display_filename, space,
                                                           lspapi_display, total_ref_in_file)
      total_ref_in_file = total_ref_in_file + 1
    else

      lspapi_display = lspapi
      item = clone(items[i])

      space = get_pads(opts.width, icon .. '  ' .. item.display_filename, lspapi_display .. ' 12')
      item.text = string.format("%s  %s%s%s 1", icon, item.display_filename, space, lspapi_display)

      trace(item.text)
      table.insert(display_items, item)
      total_ref_in_file = 1
      last_summary_idx = #display_items
    end
    -- content of code lines
    item = clone(items[i])
    item.text = require'navigator.util'.trim_and_pad(item.text)
    item.text = string.format("%4i: %s", item.lnum, item.text)
    local call_by = ""
    if item.lhs then
      call_by = '📝 '
    end

    item.text = item.text:gsub('%s*[%[%(%{]*%s*$', '')
    if item.call_by ~= nil and #item.call_by > 0 then
      trace("call_by:", #item.call_by)
      for _, value in pairs(item.call_by) do
        if value.node_text then
          local txt = value.node_text:gsub('%s*[%[%(%{]*%s*$', '')
          local endwise = '{}'
          if value.type == 'method' or value.type == 'function' then
            endwise = '()'
            call_by = ' '
          end
          if #call_by > 8 then
            call_by = call_by .. '  '
          end
          call_by = call_by .. value.kind .. txt .. endwise
          trace(item)
        end
      end
    end
    if #call_by > 1 then
      space = get_pads(win_width, item.text, call_by)
      if #space + #item.text + #call_by >= win_width then
        if #item.text + #call_by > win_width then
          log("exceeding", #item.text, #call_by, win_width)
          space = '   '
        else
          local remain = win_width - #item.text - #call_by
          log("remain", remain)
          space = string.rep(' ', remain)
        end
      end
      item.text = item.text .. space .. call_by
    end
    local tail = display_items[#display_items].text
    if tail ~= item.text then -- deduplicate
      trace(item.text)
      trace(item.call_by)
      table.insert(display_items, item)
    end
  end

  -- display_items[last_summary_idx].text=string.format("%s [%i]", display_items[last_summary_idx].filename,
  -- total_ref_in_file)
  return display_items
end

return M
