local type_to_lspkind = { c = 5, m = 7, f = 6, s = 5 }
local util = require('navigator.util')
local log = util.log
local sep = util.path_sep()
local vfn = vim.fn
local cur_dir = vfn.getcwd()

--  convert ctags line to lsp entry
local function entry_to_item(entry)
  local item = {}
  item.name, item.filename, item.line, item.remain = string.match(entry, '(.*)\t(.*)\t(%d+);(.*)')
  local type = 'combine'
  item.remain = item.remain or ''
  if item.remain:sub(1, 1) == [["]] then
    type = 'number'
  end
  if item.name == nil or item.filename == nil then
    return
  end

  if type == 'combine' then
    -- '/^type ServerResponse struct {$/;"\ts\tpackage:client'
    item.inline, item.type, item.containerName, item.ref = string.match(item.remain, '/^(.*)$/;"\t(%a)\t(.+)')
  else
    -- '"\tm\tstruct:store.Customer\ttyperef:typename:string'
    item.type, item.containerName, item.ref = string.match(item.remain, '"\t(%a)\t(.+)')
  end
  item.kind = type_to_lspkind[item.type] or 13
  item.lnum = tonumber(item.line) - 1
  item.location = {
    uri = 'file://' .. cur_dir .. sep .. item.filename,
    range = {
      start = { line = item.lnum, character = 0 },
      ['end'] = { line = item.lnum, character = 0 },
    },
  }

  item.uri = 'file://' .. cur_dir .. sep .. item.filename
  item.range = {
    start = { line = item.lnum, character = 0 },
    ['end'] = { line = item.lnum, character = 0 },
  }

  -- item.detail = (item.containerName or '') .. (item.ref or '')
  -- item.text = '[' .. kind .. ']' .. item.name .. ' ' .. item.detail

  if item.lnum == nil then
    vim.notify('incorrect ctags format, need run ctag with "-excmd=number|combine" option')
  end
  item.remain = nil
  return item
end

local function ctags_gen()
  local cmd = 'ctags' -- -x -n -u -f - ' .. vfn.expand('%:p')
  local output = _NgConfigValues.ctags.tagfile
  -- rm file first
  util.rm_file(output)
  local options = '-R --exclude=.git --exclude=node_modules --exclude=test --exclude=vendor --excmd=number '
  if _NgConfigValues.ctags then
    cmd = _NgConfigValues.ctags.cmd
    options = _NgConfigValues.ctags.options or options
  end

  local lang = vim.o.ft
  options = options .. '--language=' .. lang
  cmd = cmd .. ' ' .. options
  cmd = string.format('%s -f %s %s --language=%s', cmd, output, options, lang)
  cmd = vim.split(cmd, ' ')
  log(cmd)
  vfn.jobstart(cmd, {
    on_stdout = function(_, _, _)
      vim.notify('ctags completed')
    end,

    on_exit = function(_, data, _) -- id, data, event
      -- log(vim.inspect(data) .. "exit")
      if data and data ~= 0 then
        return vim.notify(cmd .. ' failed ' .. tostring(data), vim.lsp.log_levels.ERROR)
      else
        vim.notify('ctags generated')
      end
    end,
  })
end

local symbols_to_items = require('navigator.lspwrapper').symbols_to_items
local function ctags_symbols()
  local height = _NgConfigValues.height or 0.4
  local width = _NgConfigValues.width or 0.7
  height = math.floor(height * vfn.winheight('%'))
  width = math.floor(vim.api.nvim_get_option('columns') * width)
  local items = {}
  local ctags_file = _NgConfigValues.ctags.tagfile
  if not util.file_exists(ctags_file) then
    ctags_gen()
    vim.cmd('sleep 200m')
  end
  local cnts = util.io_read(ctags_file)
  if cnts == nil then
    return vim.notify('ctags file ' .. ctags_file .. ' not found')
  end
  cnts = vfn.split(cnts, '\n')
  for _, value in pairs(cnts) do
    local it = entry_to_item(value)
    if it then
      table.insert(items, it)
    end
  end
  cnts = nil

  local ft = vim.o.ft
  local result = symbols_to_items(items)
  if next(result) == nil then
    return vim.notify('no symbols found')
  end
  log(result[1])
  local opt = {
    api = ' ',
    ft = ft,
    bg = 'GuihuaListDark',
    data = result,
    items = result,
    enter = true,
    loc = 'top_center',
    transparency = 50,
    prompt = true,
    rawdata = true,
    rect = { height = height, pos_x = 0, pos_y = 0, width = width },
  }

  require('navigator.gui').new_list_view(opt)
end

-- gen_ctags()

local function ctags(...)
  local gen = select(1, ...)
  log(gen)
  if gen == '-g' then
    ctags_gen()
    vim.cmd('sleep 200m')
    ctags_symbols()
  else
    ctags_symbols()
  end
end

local function testitem()
  local e = [[ServerResponse	internal/clients/server.go	/^type ServerResponse struct {$/;"	s	package:client]]
  local ecombine = [[ServerResponse	internal/clients/server.go	5;/^type ServerResponse struct {$/;"	s	package:client]]
  local enumber = [[CustomerID	internal/store/models.go	17;"	m	struct:store.Customer	typeref:typename:string]]
  local enumber2 = [[CustomerDescription	internal/controllers/customer.go	27;"	c	package:controllers]]
  local enumber3 = [[add_servers	lua/navigator/lspclient/clients.lua	680;"	f]]
  local i = entry_to_item(ecombine)
  print(vim.inspect(i))

  i = entry_to_item(enumber)
  print(vim.inspect(i))

  i = entry_to_item(enumber2)
  print(vim.inspect(i))

  i = entry_to_item(enumber3)
  print(vim.inspect(i))
  i = entry_to_item(e)
  print(vim.inspect(i))
end
-- testitem()
-- gen_ctags()
-- ctags_symbols()

return {
  ctags_gen = ctags_gen,
  ctags = ctags,
  ctags_symbols = ctags_symbols,
}
