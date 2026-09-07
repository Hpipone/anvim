-- anvim: entry point — setup, commands, keymaps

local M = {}
local alert = require("anvim.status-alert")

local function register_cmd(name, fn, desc)
  local ok, err = pcall(vim.api.nvim_create_user_command, name, function()
    local ok2, err2 = pcall(fn)
    if not ok2 then alert.error(name, err2) end
  end, { desc = desc })
  if not ok then alert.error("init", "gagal buat command " .. name .. " — " .. tostring(err)) end
end

function M.setup(opts)
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

  register_cmd("Anvim", function() require("anvim.dashboard").open() end, "Open anvim dashboard")
  register_cmd("AnvimCheck", function() require("anvim.system_check").interactive() end, "Check system tools + auto-download")
  register_cmd("AnvimLogcat", function() require("anvim.logcat").open() end, "Open anvim logcat viewer")
  register_cmd("AnvimRun", function()
    local p = require("anvim.project").detect()
    require("anvim.tasks").run(p, "run")
  end, "Run app via anvim")

  if vim.g.anvim_no_default_keymaps then
    return
  end

  local ok_km1, err_km1 = pcall(vim.keymap.set, "n", "<leader>ad", "<cmd>Anvim<CR>",
    { nowait = true, silent = true, desc = "Open anvim dashboard" })
  if not ok_km1 then alert.error("init", "gagal set keymap ad — " .. tostring(err_km1)) end

  local ok_km2, err_km2 = pcall(vim.keymap.set, "n", "<leader>al", "<cmd>AnvimLogcat<CR>",
    { nowait = true, silent = true, desc = "Open anvim logcat" })
  if not ok_km2 then alert.error("init", "gagal set keymap al — " .. tostring(err_km2)) end
end

return M
