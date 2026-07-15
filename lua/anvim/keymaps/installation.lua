-- anvim: keymaps for installation progress window
-- ESC: cancel install & back to dashboard

local M = {}

function M.set(buf)
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    nowait = true, silent = true,
    callback = function()
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
    end,
  })
end

return M
