-- anvim: keymaps for installation progress window
-- ESC: cancel install & back to dashboard

local M = {}

function M.set(buf)
  vim.keymap.set("n", "<Esc>", function()
    local ok, ins = pcall(require, "anvim.installation")
    if ok then
      if ins.job_id then pcall(vim.fn.jobstop, ins.job_id); ins.job_id = nil end
      ins.install_active = false
      ins.install_cancelled = true
    end
    local util_ok, util = pcall(require, "anvim.util")
    if buf and vim.api.nvim_buf_is_valid(buf) then
      local win = vim.fn.bufwinid(buf)
      if util_ok then
        util.close_win_buf(win ~= -1 and win or nil, buf)
      else
        if win ~= -1 then pcall(vim.api.nvim_win_close, win, true) end
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
    vim.schedule(function()
      pcall(require("anvim.dashboard").open)
    end)
  end, { buffer = buf, nowait = true, silent = true, desc = "Cancel install" })
  vim.keymap.set("n", "q", function()
    local ok, ins = pcall(require, "anvim.installation")
    if ok then
      if ins.job_id then pcall(vim.fn.jobstop, ins.job_id); ins.job_id = nil end
      ins.install_active = false
      ins.install_cancelled = true
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
      local win = vim.fn.bufwinid(buf)
      if win ~= -1 then pcall(vim.api.nvim_win_close, win, true) end
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
    vim.schedule(function()
      pcall(require("anvim.dashboard").open)
    end)
  end, { buffer = buf, nowait = true, silent = true, desc = "Cancel install" })
end

return M
