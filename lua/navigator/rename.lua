-- https://github.com/lukas-reineke/dotfiles/blob/master/vim/lua/lsp/rename.lua
local M = {}
local util = require "navigator.util"
local rename_prompt = "Rename -> "

M.rename = function()
  local current_name = vim.fn.expand("<cword>")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "prompt")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_add_highlight(bufnr, -1, "RenamePrompt", 0, 0, #rename_prompt)
  vim.fn.prompt_setprompt(bufnr, rename_prompt)
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "cursor",
    width = 50,
    height = 1,
    row = -3,
    col = 1,
    style = "minimal",
    border = "single"
  })
  vim.api.nvim_win_set_option(winnr, "winhl", "Normal:Floating")
  util.map("n", "<ESC>", "<cmd>bd!<CR>", {silent = true, buffer = true})
  util.map({"n", "i"}, "<CR>", "<cmd>lua require('navigator.rename').callback()<CR>",
           {silent = true, buffer = true})
  util.map("i", "<BS>", "<ESC>xi", {silent = true, buffer = true})
  vim.cmd(string.format("normal i%s", current_name))
end

M.callback = function()
  local new_name = vim.trim(vim.fn.getline("."):sub(#rename_prompt + 1, -1))
  vim.cmd [[stopinsert]]
  vim.cmd [[bd!]]
  if #new_name == 0 or new_name == vim.fn.expand("<cword>") then
    return
  end
  local params = vim.lsp.util.make_position_params()
  params.newName = new_name
  vim.lsp.buf_request(0, "textDocument/rename", params)
end
M.rename()
-- M.callback()
return M
