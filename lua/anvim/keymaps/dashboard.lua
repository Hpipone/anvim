-- anvim: keymaps for dashboard buffer
-- snacks.nvim style — kursor bebas, minimal keymaps

local M = {}

function M.set(buf)
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>lua require('anvim.dashboard').select()<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>lua require('anvim.dashboard').close()<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>lua require('anvim.dashboard').close()<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "c", "<Cmd>lua require('anvim.dashboard').select()<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "r", "<Cmd>lua require('anvim.dashboard').select()<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "l", "<Cmd>lua require('anvim.dashboard').select()<CR>", { nowait = true, silent = true })
end

return M
