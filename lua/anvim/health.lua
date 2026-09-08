-- anvim: health — compat shim delegating to system_check (single source).
-- Kept so require("anvim.health") never crashes; all logic lives in system_check.

local M = {}

local function sys()
  return require("anvim.system_check")
end

function M.check_all()
  local s = sys()
  local results = s.check_all()
  local summary = { ok = 0, warn = 0, err = 0 }
  for _, r in pairs(results) do
    if r.found then summary.ok = summary.ok + 1 else summary.err = summary.err + 1 end
  end
  return { tools = results, summary = summary, timestamp = vim.fn.strftime("%H:%M:%S") }
end

function M.check_configured(enabled_list)
  local s = sys()
  local results = s.check_all(enabled_list)
  local summary = { ok = 0, warn = 0, err = 0 }
  for _, r in pairs(results) do
    if r.found then summary.ok = summary.ok + 1 else summary.err = summary.err + 1 end
  end
  return { tools = results, summary = summary, timestamp = vim.fn.strftime("%H:%M:%S") }
end

function M.get_checks_spec()
  return sys().get_tools_spec()
end

function M.get_missing(results)
  local t = results and results.tools or results or {}
  local missing = {}
  for name, r in pairs(t) do
    if not r.found then table.insert(missing, { name = name }) end
  end
  return missing
end

function M.format_line(name, r)
  return sys().format_line(name, r)
end

return M
