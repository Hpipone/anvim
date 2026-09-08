-- anvim: ADB device management (multi-device aware)

local M = {}
local alert = require("anvim.status-alert")

--- adb absolut (bukan "adb" mentah — PATH nvim bisa beda dari terminal).
local function adb()
  local ok, sys = pcall(require, "anvim.system_check")
  if ok and sys.adb_bin then
    local p = sys.adb_bin()
    if p and p ~= "" then return p end
  end
  if vim.fn.executable("adb") == 1 then return "adb" end
  return nil
end

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
  local adb_bin = adb()
  if not adb_bin then
    M.state.list = {}
    return {}
  end

  local ok, out = pcall(vim.fn.system, require("anvim.util").esc(adb_bin) .. " devices -l 2>/dev/null")
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

--- Tunggu device id status "device" (offline/connecting sesaat itu normal).
--- Poll tiap 1 detik sampai timeout_ms. on_done(true/false).
function M.wait_device(device_id, timeout_ms, on_done)
  on_done = on_done or function() end
  timeout_ms = timeout_ms or 10000
  local start = vim.uv.now()
  local timer = vim.uv.new_timer()
  local done = false
  local function finish(ok)
    if done then return end
    done = true
    pcall(function() timer:stop() end)
    pcall(function() timer:close() end)
    on_done(ok)
  end
  timer:start(0, 1000, vim.schedule_wrap(function()
    local ok, list = pcall(M.list)
    if ok and list then
      for _, d in ipairs(list) do
        if d.id == device_id and d.status == "device" then
          finish(true)
          return
        end
      end
    end
    if vim.uv.now() - start > timeout_ms then
      finish(false)
    end
  end))
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
  local adb_bin = adb()
  if not adb_bin then
    alert.warn("ADB not found in Neovim PATH. Launch nvim from terminal or run :AnvimCheck.")
    on_done(false)
    return
  end
  local cmd = { adb_bin }
  local active = M.get_active()
  if opts.device ~= false and active and active ~= "" and not HOST_ONLY[argv[1]] then
    vim.list_extend(cmd, { "-s", active })
  end
  for _, a in ipairs(argv) do table.insert(cmd, a) end
  -- output ke viewer logcat (device aktif dilogcat), bukan task window
  local ok_l, logcat = pcall(require, "anvim.logcat")
  if not ok_l then
    alert.error("adb", "logcat module failed to load")
    on_done("", false)
    return
  end
  logcat.exec(cmd, "adb " .. table.concat(argv, " "), function(output, ok)
    on_done(output, ok)
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
  local adb_bin = adb()
  if not adb_bin then
    alert.warn("ADB not found in Neovim PATH. Launch nvim from terminal or run :AnvimCheck.")
    on_done(false)
    return
  end
  alert.info("Pairing with " .. target .. " — check the code on your phone screen")
  local finished, prompted = false, false
  local outbuf = {}
  local exit_code = nil
  local function finish(ok)
    if finished then return end
    finished = true
    on_done(ok)
  end
  -- Baris error terakhir adb untuk pesan yang jujur (bukan "channel closed").
  local function last_error()
    for i = #outbuf, 1, -1 do
      local l = vim.trim(outbuf[i] or "")
      if l ~= "" and not l:lower():find("pairing code", 1, true) then
        return l
      end
    end
    return nil
  end
  -- NOTE skoping Lua: closure di bawah dibuat SEBELUM job ada, jadi JANGAN
  -- referensi `local job` langsung (akan mengikat global nil). Pakai holder.
  local st = {}
  local function maybe_prompt()
    if finished or prompted then return end
    local blob = table.concat(outbuf, "\n"):lower()
    -- prompt adb bisa terpotong antar chunk ("Enter pair" + "ing code: ")
    -- dan bisa lewat stdout maupun stderr → cocokkan akumulasi
    if not (blob:find("pairing code", 1, true) or (blob:find("enter", 1, true) and blob:find("code", 1, true))) then
      return
    end
    prompted = true
    vim.schedule(function()
      if finished then return end
      vim.fn.inputsave()
      local code = vim.fn.input("Pairing code: ")
      vim.fn.inputrestore()
      if code == nil or vim.trim(code) == "" then
        pcall(vim.fn.jobstop, st.job)
        finish(false)
        return
      end
      -- adb bisa sudah exit duluan (prompt + mati hampir bersamaan
      -- saat koneksi gagal) → laporkan hasil asli, bukan "channel closed"
      local sent_ok = st.job ~= nil and pcall(vim.fn.chansend, st.job, vim.trim(code) .. "\n")
      if sent_ok then return end
      if exit_code ~= nil then
        finish(exit_code == 0)
        return
      end
      local err = last_error()
      alert.warn("Pair failed for " .. target .. (err and (": " .. err) or ""))
      finish(false)
    end)
  end
  st.job = vim.fn.jobstart({ adb_bin, "pair", target }, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      if finished then return end
      for _, l in ipairs(data or {}) do table.insert(outbuf, l) end
      maybe_prompt()
    end,
    on_stderr = function(_, data)
      if finished then return end
      for _, l in ipairs(data or {}) do table.insert(outbuf, l) end
      maybe_prompt()
    end,
    on_exit = function(_, code)
      exit_code = code
      if finished then return end -- verdict sudah disampaikan di jalur kirim
      if code == 0 then
        alert.ok("Paired with " .. target .. " — now connect IP:port")
      else
        local err = last_error()
        alert.warn("Pair failed for " .. target .. (err and (": " .. err) or ""))
      end
      finish(code == 0)
    end,
  })
  if st.job == nil or st.job <= 0 then
    alert.error("adb", "pair jobstart failed")
    finish(false)
    return
  end
  -- pengaman: jangan gantung selamanya bila prompt tak kunjung datang
  vim.defer_fn(function()
    if not finished and not prompted then
      alert.warn("No pairing prompt from adb — is the IP:port correct?")
      pcall(vim.fn.jobstop, st.job)
      finish(false)
    end
  end, 120000)
end

--- Toggle: pilih command adb → isi argumen → jalan. on_done diteruskan.
function M.adb_pick(on_done)
  on_done = on_done or function() end
  if not adb() then
    alert.warn("ADB not found in Neovim PATH. Launch nvim from terminal or run :AnvimCheck.")
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
        -- adb connect exit 0 walau gagal ("failed to connect...")!
        -- Verifikasi via isi output + tunggu device ready (offline dulu itu normal).
        M.adb_exec({ "connect", target }, { device = false }, function(output, ok)
          local blob = string.lower(tostring(output or ""))
          local said_ok = blob:find("connected to", 1, true) or blob:find("already connected", 1, true)
          if not (ok and said_ok) then
            local reason = blob:match("[^\r\n]*failed[^\r\n]*") or blob:match("[^\r\n]*refused[^\r\n]*")
              or "connection rejected — same wifi? wireless debugging on?"
            alert.error("connect", target .. ": " .. vim.trim(reason))
            on_done(false)
            return
          end
          M.wait_device(target, 10000, function(ready)
            if ready then
              on_done(true)
            else
              alert.warn("Connected to " .. target .. " but device not ready — check `adb devices`")
              on_done(false)
            end
          end)
        end)
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
