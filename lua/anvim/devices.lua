-- anvim: ADB device management

local M = {}
local alert = require("anvim.status-alert")

M.state = {
  active = nil,
  list = {},
}

function M.list()
  local ok_check, _ = pcall(vim.fn.executable, "adb")
  if not ok_check or vim.fn.executable("adb") == 0 then
    M.state.list = {}
    return {}
  end

  local ok, out = pcall(vim.fn.system, "adb devices -l 2>/dev/null")
  if not ok or out == "" then
    if not ok then alert.debug("devices", "adb devices gagal — " .. tostring(out)) end
    M.state.list = {}
    return {}
  end

  local devices = {}
  for line in out:gmatch("[^\r\n]+") do
    if not line:match("^List") and not line:match("^$") then
      local id = line:match("^(%S+)")
      local status = line:match("%s+(%S+)")
      local model = line:match("model:([%w_]+)")
      if id and status then
        table.insert(devices, {
          id = id,
          status = status,
          model = model or "unknown",
        })
      end
    end
  end

  M.state.list = devices
  return devices
end

function M.set_active(id)
  M.state.active = id
end

function M.get_active()
  return M.state.active
end

function M.format(device)
  local status_icon = device.status == "device" and "✓" or "○"
  local model = device.model or "unknown"
  return string.format("%s %s (%s) [%s]", status_icon, model, device.id:sub(1, 8), device.status)
end

return M
