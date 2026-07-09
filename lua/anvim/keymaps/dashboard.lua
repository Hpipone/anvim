-- anvim: keymaps for dashboard buffer
-- dipanggil dari dashboard.lua setelah buf & win dibuat

local M = {}

function M.set(buf)
  vim.api.nvim_buf_set_keymap(buf, "n", "j", "<Cmd>lua require('anvim.dashboard').nav(1)<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "k", "<Cmd>lua require('anvim.dashboard').nav(-1)<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Down>", "<Cmd>lua require('anvim.dashboard').nav(1)<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Up>", "<Cmd>lua require('anvim.dashboard').nav(-1)<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "<Cmd>lua require('anvim.dashboard').select()<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>lua require('anvim.dashboard').close()<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "c", "<Cmd>lua require('anvim.dashboard').do_check()<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "r", "<Cmd>lua require('anvim.dashboard').do_run()<CR>", { nowait = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "l", "<Cmd>lua require('anvim.dashboard').do_logcat()<CR>", { nowait = true, silent = true })
end

return M
