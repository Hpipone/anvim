-- anvim: keymaps for dashboard buffer
-- nav: j/k/up/down ← → dedicated do_* functions for c/r/l

local M = {}

function M.set(buf)
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, silent = true, desc = desc })
  end

  map("<CR>", "<Cmd>lua require('anvim.dashboard').select()<CR>", "Select item")
  map("q",     "<Cmd>lua require('anvim.dashboard').close()<CR>", "Close dashboard")
  map("<Esc>", "<Cmd>lua require('anvim.dashboard').close()<CR>", "Close dashboard")

  map("j",     "<Cmd>lua require('anvim.dashboard').nav(1)<CR>",  "Navigate down")
  map("k",     "<Cmd>lua require('anvim.dashboard').nav(-1)<CR>", "Navigate up")
  map("<Down>","<Cmd>lua require('anvim.dashboard').nav(1)<CR>",  "Navigate down")
  map("<Up>",  "<Cmd>lua require('anvim.dashboard').nav(-1)<CR>", "Navigate up")

  map("c", "<Cmd>lua require('anvim.dashboard').do_check()<CR>",  "Check system tools")
  map("r", "<Cmd>lua require('anvim.dashboard').do_run()<CR>",    "Run app")
  map("l", "<Cmd>lua require('anvim.dashboard').do_logcat()<CR>", "Open logcat")
end

return M
