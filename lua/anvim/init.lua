-- anvim: entry point — setup, commands, keymaps
-- ponytail: minimal init, no autocommand group for this

local M = {}

function M.setup(opts)
  require("anvim.env").load()
  require("anvim.config").setup(opts)

  vim.api.nvim_create_user_command("Anvim", function()
    require("anvim.dashboard").open()
  end, { desc = "Open anvim dashboard" })

  vim.api.nvim_create_user_command("AnvimCheck", function()
    local h = require "anvim.health"
    local c = require("anvim.config").get()
    local r = h.check_configured(c.health_check.tools)
    for name, res in pairs(r.tools) do
      print(h.format_line(name, res))
    end
    print(string.format("Summary: %d OK, %d missing", r.summary.ok, r.summary.err))
  end, { desc = "Run anvim system health check" })

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
