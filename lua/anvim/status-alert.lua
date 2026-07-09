-- anvim: status-alert — central notify hub
-- pake nvim-notify kalo ada, fallback vim.notify

local M = {}
local LVL = vim.log.levels

function M.info(msg)
  local ok, n = pcall(require, "notify")
  if ok then n(msg, LVL.INFO) else vim.notify(msg, LVL.INFO) end
end

function M.warn(msg)
  local ok, n = pcall(require, "notify")
  if ok then n("⚠️ " .. msg, LVL.WARN) else vim.notify("⚠️ " .. msg, LVL.WARN) end
end

function M.error(mod, msg)
  local s = "[anvim] ERROR " .. mod .. ": " .. tostring(msg)
  local ok, n = pcall(require, "notify")
  if ok then n(s, LVL.ERROR) else vim.notify(s, LVL.ERROR) end
end

function M.debug(mod, msg)
  local s = "[anvim] " .. mod .. ": " .. tostring(msg)
  local ok, n = pcall(require, "notify")
  if ok then n(s, LVL.DEBUG) else vim.notify(s, LVL.DEBUG) end
end

function M.ok(msg)
  local ok, n = pcall(require, "notify")
  if ok then n("✓ " .. msg, LVL.INFO) else vim.notify("✓ " .. msg, LVL.INFO) end
end

return M
