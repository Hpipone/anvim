-- anvim: ADB device management (multi-device aware)

local M = {}
local alert = require("anvim.status-alert")

M.state = {
  active = nil,
  list = {},
}

local function persist_file()
  return vim.fn.expand("~") .. "/.anvim/active_device"
end

local function persist_save(id)
  pcall(function()
    vim.fn.mkdir(vim.fn.expand("~") .. "/.anvim", "p")
    if not id or id == "" then
      pcall(os.remove, persist_file())
      return
    end
    local f = io.open(persist_file(), "w")
    if f then f:write(id .. "\n") f:close() end
  end)
end

local function persist_load()
  local f = io.open(persist_file(), "r")
  if not f then return nil end
  local id = f:read("*l")
  f:close()
  if id and vim.trim(id) ~= "" then return vim.trim(id) end
  return nil
end

local function parse_devices(out)
  local devices = {}
  if not out or out == "" then return devices end
  for line in out:gmatch("[^\r\n]+") do
    local t = vim.trim(line)
    if t ~= "" and not t:match("^List of devices") and not t:match("^%*") and not t:match("^adb server") and not t:match("^daemon") then
      local id, status = t:match("^(%S+)%s+(%S+)")
      if id and status and id ~= "" then
        -- filter baris non-device (misal "adb: ...")
        if not id:match("^adb") then
          local model = t:match("model:([%w%_%-%.]+)")
          local product = t:match("product:([%w%_%-%.]+)")
          table.insert(devices, {
            id = id,
            status = status,
            model = model or product or "unknown",
            raw = t,
          })
        end
      end
    end
  end
  return devices
end

M._parse = parse_devices

function M.list()
  if vim.fn.executable("adb") == 0 then
    M.state.list = {}
    return {}
  end

  local ok, out = pcall(vim.fn.system, "adb devices -l 2>/dev/null")
  if not ok or not out then
    alert.debug("devices", "adb devices gagal — " .. tostring(out))
    M.state.list = {}
    return {}
  end

  local devices = parse_devices(out)
  M.state.list = devices

  -- validasi active masih ada
  if M.state.active then
    local still = false
    for _, d in ipairs(devices) do if d.id == M.state.active then still = true break end end
    if not still then M.state.active = nil end
  end
  -- restore persisted active jika masih terhubung
  if not M.state.active then
    local saved = persist_load()
    if saved then
      for _, d in ipairs(devices) do
        if d.id == saved then M.state.active = saved break end
      end
    end
  end
  -- auto-pilih jika cuma 1 device online
  if not M.state.active and #devices == 1 and devices[1].status == "device" then
    M.state.active = devices[1].id
  end

  -- warning untuk unauthorized/offline
  for _, d in ipairs(devices) do
    if d.status == "unauthorized" then
      alert.warn("Device " .. d.id .. " unauthorized — setujui RSA di HP.")
      break
    elseif d.status == "offline" then
      alert.warn("Device " .. d.id .. " offline — cabut/colok ulang atau adb reconnect.")
      break
    end
  end

  return devices
end

function M.set_active(id)
  if not id or id == "" then
    M.state.active = nil
    persist_save(nil)
    return true
  end
  for _, d in ipairs(M.state.list) do
    if d.id == id then
      if d.status ~= "device" then
        alert.warn("Device " .. id .. " status " .. d.status .. " — tetap dipilih tapi task mungkin gagal.")
      end
      M.state.active = id
      persist_save(id)
      return true
    end
  end
  alert.warn("Device " .. id .. " tidak ada di daftar. Refresh dulu.")
  return false
end

function M.get_active()
  return M.state.active
end

--- Args -s <device> untuk semua adb call (nil jika single/tidak ada).
function M.device_args()
  if M.state.active then
    return { "-s", M.state.active }
  end
  return {}
end

function M.format(device)
  local status_icon = device.status == "device" and "✓" or "○"
  local model = device.model or "unknown"
  return string.format("%s %s (%s) [%s]", status_icon, model, device.id, device.status)
end

return M
