-- anvim: keymaps for dashboard buffer
-- nav: hanya atas/bawah (j/k/up/down/gg/G). Gerak kiri/kanan dikunci.

local M = {}

function M.set(buf)
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, silent = true, desc = desc })
  end
  local nop = function(lhs)
    vim.keymap.set("n", lhs, "<Nop>", { buffer = buf, nowait = true, silent = true })
  end

  map("<CR>", "<Cmd>lua require('anvim.dashboard').select()<CR>", "Select item")
  map("q",     "<Cmd>lua require('anvim.dashboard').close()<CR>", "Close dashboard")
  map("<Esc>", "<Cmd>lua require('anvim.dashboard').close()<CR>", "Close dashboard")

  map("j",     "<Cmd>lua require('anvim.dashboard').nav(1)<CR>",  "Navigate down")
  map("k",     "<Cmd>lua require('anvim.dashboard').nav(-1)<CR>", "Navigate up")
  map("<Down>","<Cmd>lua require('anvim.dashboard').nav(1)<CR>",  "Navigate down")
  map("<Up>",  "<Cmd>lua require('anvim.dashboard').nav(-1)<CR>", "Navigate up")
  map("gg", "<Cmd>lua require('anvim.dashboard').top()<CR>", "First item")
  map("G",  "<Cmd>lua require('anvim.dashboard').bottom()<CR>", "Last item")

  -- kunci gerak horizontal & word-jump (cursor snap juga jaga via autocmd)
  -- catatan: "l" tetap buka logcat (mapping di bawah menimpa Nop)
  for _, lhs in ipairs({ "h", "<Left>", "<Right>", "0", "$", "^", "w", "b", "e", "W", "B", "E", "<Home>", "<End>" }) do
    nop(lhs)
  end

  map("c", "<Cmd>lua require('anvim.dashboard').do_check()<CR>",  "Check system tools")
  map("r", "<Cmd>lua require('anvim.dashboard').do_run()<CR>",    "Run app")
  map("l", "<Cmd>lua require('anvim.dashboard').do_logcat()<CR>", "Open logcat")
  map("x", "<Cmd>lua require('anvim.dashboard').do_cancel_task()<CR>", "Cancel running task")
  map("e", "<Cmd>lua require('anvim.dashboard').do_emulator()<CR>", "Launch emulator")
  map("t", "<Cmd>lua require('anvim.dashboard').do_test()<CR>", "Run tests")
  map("R", "<Cmd>lua require('anvim.dashboard').do_rerun()<CR>", "Rerun last task")
end

return M
