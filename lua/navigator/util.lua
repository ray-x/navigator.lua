-- retreives data form file
-- and line to highlight
-- Some of function copied from https://github.com/RishabhRD/nvim-lsputils
local M = {log_path = vim.lsp.get_log_path()}
function M.get_data_from_file(filename, startLine)
  local displayLine
  if startLine < 3 then
    displayLine = startLine
    startLine = 0
  else
    startLine = startLine - 2
    displayLine = 2
  end
  local uri = "file:///" .. filename
  local bufnr = vim.uri_to_bufnr(uri)
  vim.fn.bufload(bufnr)
  local data = vim.api.nvim_buf_get_lines(bufnr, startLine, startLine + 8, false)
  if data == nil or vim.tbl_isempty(data) then
    startLine = nil
  else
    local len = #data
    startLine = startLine + 1
    for i = 1, len, 1 do
      data[i] = startLine .. " " .. data[i]
      startLine = startLine + 1
    end
  end
  return {data = data, line = displayLine}
end

function M.get_base(path)
  local len = #path
  for i = len, 1, -1 do
    if path:sub(i, i) == "/" then
      local ret = path:sub(i + 1, len)
      return ret
    end
  end
end

local function getDir(path)
  local data = {}
  local len = #path
  if len <= 1 then
    return nil
  end
  local last_index = 1
  for i = 2, len do
    local cur_char = path:sub(i, i)
    if cur_char == "/" then
      local my_data = path:sub(last_index + 1, i - 1)
      table.insert(data, my_data)
      last_index = i
    end
  end
  return data
end

function M.get_relative_path(base_path, my_path)
  local base_data = getDir(base_path)
  local my_data = getDir(my_path)
  local base_len = #base_data
  local my_len = #my_data

  if base_len > my_len then
    return my_path
  end

  if base_data[1] ~= my_data[1] then
    return my_path
  end

  local cur = 0
  for i = 1, base_len do
    if base_data[i] ~= my_data[i] then
      break
    end
    cur = i
  end
  local data = ""
  for i = cur + 1, my_len do
    data = data .. my_data[i] .. "/"
  end
  data = data .. M.get_base(my_path)
  return data
end

local level = "error"
if _NgConfigValues.debug == true then
  level = "debug"
elseif _NgConfigValues.debug == "trace" then
  level = "trace"
end

local default_config = {plugin = "navigator", use_console = false, use_file = true, level = level}
M._log = require("guihua.log").new({level = default_config.level}, true)

-- add log to you lsp.log
M.log = M._log.info
M.info = M._log.info
M.trace = M._log.trace
M.error = M._log.error

function M.fmt(...)
  M._log.fmt_info(...)
end

function M.split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

function M.quickfix_extract(line)
  -- check if it is a line of file pos been selected
  local split = M.split
  line = vim.trim(line)
  local sep = split(line, " ")
  if #sep < 2 then
    M.log(line)
    return nil
  end
  sep = split(sep[1], ":")
  if #sep < 3 then
    M.log(line)
    return nil
  end
  local location = {
    uri = "file:///" .. sep[1],
    range = {start = {line = sep[2] - 3 > 0 and sep[2] - 3 or 1}}
  }
  location.range["end"] = {line = sep[2] + 15}
  return location
end

function M.getArgs(inputstr)
  local sep = "%s"
  local t = {}
  local cmd
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    if not cmd then
      cmd = str
    else
      table.insert(t, str)
    end
  end
  return cmd, t
end

function M.p(t)
  print(vim.inspect(t))
end

function M.printError(msg)
  vim.cmd("echohl ErrorMsg")
  vim.cmd(string.format([[echomsg '%s']], msg))
  vim.cmd("echohl None")
end

function M.reload()
  vim.lsp.stop_client(vim.lsp.get_active_clients())
  vim.cmd [[edit]]
end

function M.open_log()
  local path = vim.lsp.get_log_path()
  vim.cmd("edit " .. path)
end

function table.pack(...)
  return {n = select("#", ...), ...}
end

function M.show(...)
  local string = ""

  local args = table.pack(...)

  for i = 1, args.n do
    string = string .. tostring(args[i]) .. "\t"
  end

  return string .. "\n"
end

function M.split2(s, sep)
  local fields = {}

  sep = sep or " "
  local pattern = string.format("([^%s]+)", sep)
  string.gsub(s, pattern, function(c)
    fields[#fields + 1] = c
  end)

  return fields
end

function M.trim_and_pad(txt)
  local len = #txt
  if len <= 1 then
    return
  end
  local tab_en = txt[1] == '\t' or false
  txt = vim.trim(txt)
  if tab_en then
    if len - txt > 2 then
      return '    ' .. txt
    end
    if len - txt > 0 then
      return '  ' .. txt
    end
  end
  local rep = math.min(12, len - #txt)
  return string.rep('  ', rep / 4) .. txt
end

M.open_file = function(filename)
  vim.api.nvim_command(string.format("e! %s", filename))
end

M.open_file_at = function(filename, line, col)
  vim.api.nvim_command(string.format("e! +%s %s", line, filename))
  col = col or 1
  vim.api.nvim_command(string.format("normal! %dl", col - 1))
end

function M.exists(var)
  for k, _ in pairs(_G) do
    if k == var then
      return true
    end
  end
end

function M.partial(func, arg)
  return (function(...)
    return func(arg, ...)
  end)
end

local exclude_ft = {"scrollbar", "help", "NvimTree"}
function M.exclude(fname)
  for i = 1, #exclude_ft do
    if string.find(fname, exclude_ft[i]) then
      return true
    end
  end
  return false
end

--- virtual text

-- name space search
local nss
local api = vim.api
local bufs

function M.set_virt_eol(bufnr, lnum, chunks, priority, id)
  if nss == nil then
    nss = api.nvim_create_namespace("navigator_search")
  end
  bufnr = bufnr == 0 and api.nvim_get_current_buf() or bufnr
  bufs[bufnr] = true
  -- id may be nil
  return api.nvim_buf_set_extmark(bufnr, nss, lnum, -1,
                                  {id = id, virt_text = chunks, priority = priority})
end

function M.clear_buf(bufnr)
  if not bufnr then
    return
  end
  bufnr = bufnr == 0 and api.nvim_get_current_buf() or bufnr
  if bufs[bufnr] then
    if api.nvim_buf_is_valid(bufnr) then
      api.nvim_buf_clear_namespace(bufnr, nss, 0, -1)
      -- nvim_buf_del_extmark
    end
    bufs[bufnr] = nil
  end
end

function M.clear_all_buf()
  for bufnr in pairs(bufs) do
    M.clear_buf(bufnr)
  end
  bufs = {}
end

return M
