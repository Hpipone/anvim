-- anvim: entry point — setup, commands, keymaps
-- ponytail: guard command doang, config tiap kali di-merge

local M = {}

function M.setup(opts)
  require("anvim.config").setup(opts)

  if vim.g.anvim_loaded then return end
  vim.g.anvim_loaded = 1

  vim.api.nvim_create_user_command("Anvim", function()
    require("anvim.dashboard").open()
  end, { desc = "Open anvim dashboard" })

  vim.api.nvim_create_user_command("AnvimCheck", function()
    require("anvim.help_check").interactive()
  end, { desc = "Run anvim system health check + auto-download" })

  vim.api.nvim_create_user_command("AnvimLogcat", function()
    require("anvim.logcat").open()
  end, { desc = "Open anvim logcat viewer" })

  if vim.g.anvim_no_default_keymaps then
    return
  end

  local wk = vim.g.mapleader or "\\"
  vim.api.nvim_set_keymap("n", wk .. "ad", "<cmd>Anvim<CR>",
    { nowait = true, silent = true, desc = "Open anvim dashboard" })
  vim.api.nvim_set_keymap("n", wk .. "al", "<cmd>AnvimLogcat<CR>",
    { nowait = true, silent = true, desc = "Open anvim logcat" })
end

return M
