-- anvim: entry point — setup, commands, keymaps
-- ponytail: silent plugin-manager detection, guard command doang

local M = {}
local alert = require("anvim.status-alert")

function M.setup(opts)
  -- silent detect plugin manager — tanpa notif
  if vim.g.anvim_loader == nil then
    vim.g.anvim_loader = "lazy"
  end

  local ok, err = pcall(require, "anvim.config")
  if not ok then
    alert.error("init", "gagal load config — " .. tostring(err))
    return
  end
  require("anvim.config").setup(opts)

  if vim.g.anvim_loaded then return end
  vim.g.anvim_loaded = 1

  local ok_cmd1, err_cmd1 = pcall(vim.api.nvim_create_user_command, "Anvim", function()
    local ok2, err2 = pcall(function() require("anvim.dashboard").open() end)
    if not ok2 then alert.error("Anvim", err2) end
  end, { desc = "Open anvim dashboard" })
  if not ok_cmd1 then alert.error("init", "gagal buat command Anvim — " .. tostring(err_cmd1)) end

  local ok_cmd2, err_cmd2 = pcall(vim.api.nvim_create_user_command, "AnvimCheck", function()
    local ok2, err2 = pcall(function() require("anvim.help_check").interactive() end)
    if not ok2 then alert.error("AnvimCheck", err2) end
  end, { desc = "Run anvim system health check + auto-download" })
  if not ok_cmd2 then alert.error("init", "gagal buat command AnvimCheck — " .. tostring(err_cmd2)) end

  local ok_cmd3, err_cmd3 = pcall(vim.api.nvim_create_user_command, "AnvimLogcat", function()
    local ok2, err2 = pcall(function() require("anvim.logcat").open() end)
    if not ok2 then alert.error("AnvimLogcat", err2) end
  end, { desc = "Open anvim logcat viewer" })
  if not ok_cmd3 then alert.error("init", "gagal buat command AnvimLogcat — " .. tostring(err_cmd3)) end

  local ok_cmd4, err_cmd4 = pcall(vim.api.nvim_create_user_command, "AnvimRun", function()
    local ok2, err2 = pcall(function()
      local p = require("anvim.project").detect()
      require("anvim.tasks").run(p, "run")
    end)
    if not ok2 then alert.error("AnvimRun", err2) end
  end, { desc = "Run app via anvim" })
  if not ok_cmd4 then alert.error("init", "gagal buat command AnvimRun — " .. tostring(err_cmd4)) end

  if vim.g.anvim_no_default_keymaps then
    return
  end

  local wk = vim.g.mapleader or "\\"
  local ok_km1, err_km1 = pcall(vim.keymap.set, "n", wk .. "ad", "<cmd>Anvim<CR>",
    { nowait = true, silent = true, desc = "Open anvim dashboard" })
  if not ok_km1 then alert.error("init", "gagal set keymap ad — " .. tostring(err_km1)) end

  local ok_km2, err_km2 = pcall(vim.keymap.set, "n", wk .. "al", "<cmd>AnvimLogcat<CR>",
    { nowait = true, silent = true, desc = "Open anvim logcat" })
  if not ok_km2 then alert.error("init", "gagal set keymap al — " .. tostring(err_km2)) end
end

return M
