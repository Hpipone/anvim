-- anvim: keymaps for installation progress window
-- ESC: cancel install & back to dashboard

local M = {}

function M.set(buf)
  vim.keymap.set("n", "<Esc>", function()
    local ins = require("anvim.installation")
    if ins.job_id then pcall(vim.fn.jobstop, ins.job_id); ins.job_id = nil end
    ins.install_active = false
    ins.install_cancelled = true
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    vim.schedule(function()
      pcall(require("anvim.dashboard").open)
    end)
  end, { buffer = buf, nowait = true, silent = true, desc = "Cancel install" })
end

return M
