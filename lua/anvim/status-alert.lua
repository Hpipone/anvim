-- anvim: status-alert — central notify hub
-- semua modul panggil sini, biar konsisten & gampang diubah

local M = {}
local LVL = vim.log.levels

function M.info(msg)
  vim.notify("[anvim] " .. msg, LVL.INFO)
end

function M.warn(msg)
  vim.notify("⚠️ " .. msg, LVL.WARN)
end

function M.error(mod, msg)
  vim.notify("[anvim] ERROR " .. mod .. ": " .. tostring(msg), LVL.ERROR)
end

function M.debug(mod, msg)
  vim.notify("[anvim] " .. mod .. ": " .. tostring(msg), LVL.DEBUG)
end

function M.ok(mod, msg)
  vim.notify("[anvim] ✓ " .. mod .. ": " .. msg, LVL.INFO)
end

function M.fail(mod, msg)
  vim.notify("[anvim] ✗ " .. mod .. ": " .. msg, LVL.ERROR)
end

return M
