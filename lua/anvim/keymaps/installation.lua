-- anvim: keymaps for installation progress window
-- dipanggil dari help_check.lua setelah progress buf dibuat

local M = {}

function M.set(buf, get_active)
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    nowait = true, silent = true,
    callback = function()
      if not get_active() then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end,
  })
end

return M
