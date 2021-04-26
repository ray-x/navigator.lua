local gui = require "navigator.gui"
local util = require "navigator.util"
local log = util.log
local partial = util.partial
local lsphelper = require "navigator.lspwrapper"
local cwd = vim.fn.getcwd(0)
local M = {}

local match_parameter = function(result)
  local signatures = result.signatures
  if #signatures < 1 then
    return result
  end

  local signature = signatures[1]
  local activeParameter = result.activeParameter or signature.activeParameter
  if activeParameter == nil then
    return result
  end

  if #signature.parameters < 2 or activeParameter + 1 > #signature.parameters then
    return result
  end

  local nextParameter = signature.parameters[activeParameter + 1]

  local label = signature.label
  if type(nextParameter.label) == "table" then -- label = {2, 4} c style
    local range = nextParameter.label
    label =
      label:sub(1, range[1]) ..
      [[`]] .. label:sub(range[1] + 1, range[2]) .. [[`]] .. label:sub(range[2] + 1, #label + 1)
    signature.label = label
  else
    if type(nextParameter.label) == "string" then -- label = 'par1 int'
      local i, j = label:find(nextParameter.label, 1, true)
      if i ~= nil then
        label = label:sub(1, i - 1) .. [[`]] .. label:sub(i, j) .. [[`]] .. label:sub(j + 1, #label + 1)
        signature.label = label
      end
    end
  end
end

local function signature_handler(err, method, result, _, bufnr, config)
  -- log(result)
  if not (result and result.signatures and result.signatures[1]) then
    return
  end
  match_parameter(result)
  local lines = vim.lsp.util.convert_signature_help_to_markdown_lines(result)
  if vim.tbl_isempty(lines) then
    return
  end
  vim.lsp.util.focusable_preview(
    method .. "lsp_signature",
    function()
      lines = vim.lsp.util.trim_empty_lines(lines)
      return lines, vim.lsp.util.try_trim_markdown_code_blocks(lines)
    end
  )
end
return {signature_handler = signature_handler}
