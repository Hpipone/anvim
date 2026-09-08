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
    alert.debug("devices", "adb devices failed — " .. tostring(out))
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
      alert.warn("Device " .. d.id .. " unauthorized — approve RSA on the phone.")
      break
    elseif d.status == "offline" then
      alert.warn("Device " .. d.id .. " offline — replug or run adb reconnect.")
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
        alert.warn("Device " .. id .. " status " .. d.status .. " — kept selected but tasks may fail.")
      end
      M.state.active = id
      persist_save(id)
      return true
    end
  end
  alert.warn("Device " .. id .. " not in the list. Refresh first.")
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

--- Toggle preset adb. device=true → tambah -s active (kecuali host-only).
M.ADB_PRESETS = {
  { label = "pair (IP:port)…", cmd = "pair", arg = "IP:port, e.g. 192.168.1.5:37099", device = false },
  { label = "connect (IP:port)…", cmd = "connect", arg = "IP:port, e.g. 192.168.1.5:5555", device = false },
  { label = "disconnect", cmd = "disconnect", device = false },
  { label = "devices -l", cmd = "devices -l", device = false },
  { label = "reconnect", cmd = "reconnect", device = false },
  { label = "reboot device", cmd = "reboot", device = true },
  { label = "shell…", cmd = "shell", arg = "shell command (empty = interactive note)", device = true },
  { label = "custom adb…", custom = true },
}

local HOST_ONLY = { pair = true, connect = true, disconnect = true, devices = true, reconnect = true, ["version"] = true }

--- Jalankan argv adb via task window. on_done(ok). Tambah -s bila cocok.
function M.adb_exec(argv, opts, on_done)
  opts = opts or {}
  on_done = on_done or function() end
  if vim.fn.executable("adb") == 0 then
    alert.warn("ADB required. Run :AnvimCheck to install.")
    on_done(false)
    return
  end
  local cmd = { "adb" }
  local active = M.get_active()
  if opts.device ~= false and active and active ~= "" and not HOST_ONLY[argv[1]] then
    vim.list_extend(cmd, { "-s", active })
  end
  for _, a in ipairs(argv) do table.insert(cmd, a) end
  local ok_t, tasks = pcall(require, "anvim.tasks")
  if not ok_t then
    alert.error("adb", "tasks module failed to load")
    on_done(false)
    return
  end
  tasks.run_custom(cmd, "adb " .. table.concat(argv, " "), function(_, ok)
    on_done(ok)
  end)
end

local function input_line(prompt, on_ok)
  vim.fn.inputsave()
  local raw = vim.fn.input(prompt)
  vim.fn.inputrestore()
  if raw == nil or vim.trim(raw) == "" then return end
  on_ok(vim.trim(raw))
end

--- Pairing wireless: adb pair butuh kode dari layar HP.
--- Alur: start pair → tunggu prompt kode → input user → chansend → done.
function M.adb_pair(target, on_done)
  on_done = on_done or function() end
  if vim.fn.executable("adb") == 0 then
    alert.warn("ADB required. Run :AnvimCheck to install.")
    on_done(false)
    return
  end
  alert.info("Pairing with " .. target .. " — check the code on your phone screen")
  local finished = false
  local function finish(ok)
    if finished then return end
    finished = true
    on_done(ok)
  end
  local job = vim.fn.jobstart({ "adb", "pair", target }, {
    stdout_buffered = false,
    on_stdout = function(_, data)
      if finished then return end
      local blob = table.concat(data or {}, "\n"):lower()
      if blob:find("pairing code") or blob:find("enter.*code") then
        vim.schedule(function()
          if finished then return end
          vim.fn.inputsave()
          local code = vim.fn.input("Pairing code: ")
          vim.fn.inputrestore()
          if code == nil or vim.trim(code) == "" then
            pcall(vim.fn.jobstop, job)
            finish(false)
            return
          end
          pcall(vim.fn.chansend, job, vim.trim(code) .. "\n")
        end)
      end
    end,
    on_stderr = function() end,
    on_exit = function(_, code)
      if code == 0 then
        alert.ok("Paired with " .. target .. " — now connect IP:port")
      else
        alert.warn("Pair failed for " .. target)
      end
      finish(code == 0)
    end,
  })
  if job == nil or job <= 0 then
    alert.error("adb", "pair jobstart failed")
    finish(false)
  end
end

--- Toggle: pilih command adb → isi argumen → jalan. on_done diteruskan.
function M.adb_pick(on_done)
  on_done = on_done or function() end
  if vim.fn.executable("adb") == 0 then
    alert.warn("ADB required. Run :AnvimCheck to install.")
    on_done(false)
    return
  end
  local labels = {}
  for _, p in ipairs(M.ADB_PRESETS) do table.insert(labels, p.label) end
  vim.ui.select(labels, { prompt = "adb command:" }, function(choice)
    if not choice then on_done(false) return end
    local preset
    for _, p in ipairs(M.ADB_PRESETS) do if p.label == choice then preset = p break end end
    if not preset then on_done(false) return end
    if preset.custom then
      input_line("adb ", function(raw)
        if raw:match("^adb%s+") then raw = raw:gsub("^adb%s+", "") end
        local argv = {}
        for w in raw:gmatch("%S+") do table.insert(argv, w) end
        if #argv == 0 then on_done(false) return end
        M.adb_exec(argv, { device = true }, on_done)
      end)
      return
    end
    if preset.cmd == "connect" then
      input_line("Device IP:port: ", function(target)
        if not target:match("^[%w%.%-]+:%d+$") then
          alert.warn("Format must be IP:port, e.g. 192.168.1.5:5555")
          on_done(false)
          return
        end
        M.adb_exec({ "connect", target }, { device = false }, on_done)
      end)
      return
    end
    if preset.cmd == "pair" then
      input_line("Pair IP:port: ", function(target)
        if not target:match("^[%w%.%-]+:%d+$") then
          alert.warn("Format must be IP:port, e.g. 192.168.1.5:37099")
          on_done(false)
          return
        end
        M.adb_pair(target, on_done)
      end)
      return
    end
    if preset.arg and preset.cmd == "shell" then
      input_line("adb shell: ", function(line)
        local argv = { "shell" }
        for w in line:gmatch("%S+") do table.insert(argv, w) end
        M.adb_exec(argv, { device = true }, on_done)
      end)
      return
    end
    local argv = {}
    for w in preset.cmd:gmatch("%S+") do table.insert(argv, w) end
    M.adb_exec(argv, { device = preset.device }, on_done)
  end)
end

return M
