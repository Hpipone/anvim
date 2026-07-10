-- anvim: keymaps for installation progress window
-- ESC: cancel install & back to dashboard

local M = {}

function M.set(buf, get_active)
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    nowait = true, silent = true,
    callback = function()
      local hc = require("anvim.help_check")
      hc.install_active = false
      hc.install_cancelled = true
      if buf and vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      -- reopen dashboard
      vim.schedule(function()
        pcall(require("anvim.dashboard").open)
      end)
    end,
  })
end

return M
