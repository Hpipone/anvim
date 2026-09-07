-- anvim: emulator manager — list/launch/kill AVD, boot wait, auto-select
-- Binary: $ANDROID_HOME/emulator/emulator atau PATH `emulator`.

local M = {}
local alert = require("anvim.status-alert")
local util = require("anvim.util")
local OS = util.OS

local function cfg_boot_timeout()
  local ok, c = pcall(function() return require("anvim.config").get() end)
  if ok and c and c.emulator and c.emulator.boot_timeout_ms then
    return c.emulator.boot_timeout_ms
  end
  return 120000
end

--- Cari binary emulator. Return path atau nil.
function M.find_binary()
  local exe = vim.fn.exepath(OS == "windows" and "emulator.exe" or "emulator")
  if exe and exe ~= "" then return exe end
  local lb = util.local_bin()
  local cands = {
    lb .. (OS == "windows" and "\\emulator.exe" or "/emulator"),
  }
  local ah = vim.env.ANDROID_HOME or vim.env.ANDROID_SDK_ROOT
  if ah and ah ~= "" then
    table.insert(cands, ah .. "/emulator/emulator")
  end
  local home = vim.fn.expand("~")
  table.insert(cands, home .. "/Android/Sdk/emulator/emulator")
  table.insert(cands, home .. "/Library/Android/sdk/emulator/emulator")
  table.insert(cands, home .. "/android/emulator/emulator")
  for _, p in ipairs(cands) do
    if vim.fn.executable(p) == 1 then return p end
  end
  return nil
end

--- Parse output `emulator -list-avds` → {names}.
function M._parse_avds(out)
  local names = {}
  if not out or out == "" then return names end
  for line in out:gmatch("[^\r\n]+") do
    local t = vim.trim(line)
    if t ~= "" and not t:match("^INFO") and not t:match("^WARNING") and not t:match("^ERROR") then
      -- AVD name satu token tanpa spasi pada umumnya
      if not t:find("%s") then
        table.insert(names, t)
      end
    end
  end
  return names
end

--- List AVD terinstall. Return {names} (kosong jika binary hilang).
function M.list_avds()
  local bin = M.find_binary()
  if not bin then return {} end
  local ok, out = pcall(vim.fn.system, util.esc(bin) .. " -list-avds 2>/dev/null")
  if not ok or not out then return {} end
  return M._parse_avds(out)
end

--- Map AVD name → device id untuk emulator yang sedang jalan.
--- Query `adb -s <id> emu avd name` per device emulator-*.
function M.running_map(dev_list)
  local map = {}
  if vim.fn.executable("adb") == 0 then return map end
  dev_list = dev_list or {}
  for _, d in ipairs(dev_list) do
    if d.id:match("^emulator%-") and d.status == "device" then
      local ok, out = pcall(vim.fn.system, "adb -s " .. util.esc(d.id) .. " emu avd name 2>/dev/null")
      if ok and out then
        local name = vim.trim(out):gmatch("[^\r\n]+")()
        if name and name ~= "" and name ~= "OK" then
          map[name] = d.id
        else
          map["?:" .. d.id] = d.id
        end
      end
    end
  end
  return map
end

--- Build launch cmd. opts: {cold_boot=true, wipe_data=false, extra={...}}
function M.build_launch_cmd(avd, opts)
  opts = opts or {}
  local bin = M.find_binary() or "emulator"
  local cmd = { bin, "-avd", avd }
  if opts.wipe_data then
    table.insert(cmd, "-wipe-data")
  elseif opts.cold_boot ~= false then
    table.insert(cmd, "-no-snapshot-load")
  end
  for _, a in ipairs(opts.extra or {}) do table.insert(cmd, a) end
  return cmd
end

--- Parse getprop sys.boot_completed → true jika "1".
function M._boot_done(out)
  return out and vim.trim(out):sub(1, 1) == "1" or false
end

--- Poll boot_completed sampai 1 / timeout. on_done(true/false).
function M.wait_boot(device_id, timeout_ms, on_done)
  on_done = on_done or function() end
  timeout_ms = timeout_ms or cfg_boot_timeout()
  if not device_id then on_done(false) return end
  local start = vim.uv.now()
  local timer = vim.uv.new_timer()
  local function poll()
    if vim.uv.now() - start > timeout_ms then
      if timer then pcall(function() timer:stop() end) pcall(function() timer:close() end) end
      alert.warn("Emulator boot timeout (" .. math.floor(timeout_ms / 1000) .. "s) — cek manual via adb devices.")
      on_done(false)
      return
    end
    local ok, out = pcall(vim.fn.system, "adb -s " .. util.esc(device_id) .. " shell getprop sys.boot_completed 2>/dev/null")
    if ok and M._boot_done(out) then
      if timer then pcall(function() timer:stop() end) pcall(function() timer:close() end) end
      alert.ok("Emulator booted: " .. device_id)
      on_done(true)
      return
    end
  end
  timer:start(0, 2000, vim.schedule_wrap(poll))
end

--- Cari device emulator baru yang muncul setelah launch (poll adb devices).
local function wait_new_emulator(known_ids, timeout_ms, on_done)
  local start = vim.uv.now()
  local timer = vim.uv.new_timer()
  timer:start(0, 2000, vim.schedule_wrap(function()
    if vim.uv.now() - start > timeout_ms then
      pcall(function() timer:stop() end) pcall(function() timer:close() end)
      on_done(nil)
      return
    end
    local ok, dev = pcall(require, "anvim.devices")
    if ok then
      local list = dev.list()
      for _, d in ipairs(list) do
        if d.id:match("^emulator%-") and not known_ids[d.id] then
          pcall(function() timer:stop() end) pcall(function() timer:close() end)
          on_done(d.id)
          return
        end
      end
    end
  end))
end

--- Launch AVD (detached) lalu auto-select + wait boot.
function M.launch(avd, opts, on_done)
  on_done = on_done or function() end
  opts = opts or {}
  if not avd or avd == "" then alert.warn("AVD name kosong.") on_done(false) return end
  local bin = M.find_binary()
  if not bin then
    alert.warn("Emulator binary tidak ditemukan. Install Android SDK Emulator + set ANDROID_HOME.")
    on_done(false)
    return
  end
  local cmd = M.build_launch_cmd(avd, opts)
  alert.info("Launching emulator: " .. avd .. (opts.wipe_data and " (wipe-data)" or ""))
  -- snapshot device yang sudah ada agar bisa deteksi yang baru muncul
  local known = {}
  pcall(function()
    for _, d in ipairs(require("anvim.devices").list()) do known[d.id] = true end
  end)
  local job = vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code ~= 0 then
        alert.error("emulator", avd .. " exit code " .. tostring(code))
      end
    end,
  })
  if job == nil or job <= 0 then
    alert.error("emulator", "jobstart gagal: " .. table.concat(cmd, " "))
    on_done(false)
    return
  end
  local timeout = cfg_boot_timeout()
  wait_new_emulator(known, math.min(timeout, 60000), function(new_id)
    if not new_id then
      alert.warn("Emulator " .. avd .. " launching — belum muncul di adb devices, cek manual.")
      on_done(true)
      return
    end
    pcall(function() require("anvim.devices").set_active(new_id) end)
    alert.info("Emulator muncul: " .. new_id .. " — menunggu boot...")
    M.wait_boot(new_id, timeout, function(booted)
      on_done(booted)
    end)
  end)
end

--- Kill emulator yang sedang jalan via `adb -s <id> emu kill`.
function M.kill(device_id, on_done)
  on_done = on_done or function() end
  if not device_id or device_id == "" then alert.warn("Pilih emulator dulu.") on_done(false) return end
  if vim.fn.executable("adb") == 0 then alert.warn("Butuh ADB.") on_done(false) return end
  alert.info("Killing emulator: " .. device_id)
  local ok, out = pcall(vim.fn.system, "adb -s " .. util.esc(device_id) .. " emu kill 2>&1")
  if not ok then
    alert.error("emulator", "kill gagal: " .. tostring(out))
    on_done(false)
    return
  end
  -- bersihkan active jika yang di-kill adalah active
  pcall(function()
    local dev = require("anvim.devices")
    if dev.get_active() == device_id then dev.set_active(nil) end
  end)
  -- validasi: device hilang dari list (tunggu sebentar)
  vim.defer_fn(function()
    local gone = true
    pcall(function()
      for _, d in ipairs(require("anvim.devices").list()) do
        if d.id == device_id then gone = false end
      end
    end)
    if gone then alert.ok("Emulator dimatikan: " .. device_id) else alert.warn(device_id .. " masih terlihat — coba lagi.") end
    on_done(gone)
  end, 1500)
end

--- Picker launch: pilih AVD → pilih mode → launch.
function M.pick_and_launch()
  local avds = M.list_avds()
  if #avds == 0 then
    if not M.find_binary() then
      alert.warn("Emulator tidak ditemukan. Install via Android Studio SDK Manager (SDK Tools → Android Emulator) + buat AVD.")
    else
      alert.warn("Belum ada AVD. Buat dulu: emulator -list-avds kosong. (Android Studio → Device Manager → Create Device)")
    end
    return
  end
  local function choose_mode(avd)
    vim.ui.select({ "Normal (cold boot)", "Wipe data", "Quick boot (snapshot)" }, { prompt = "Launch " .. avd .. ":" }, function(mode)
      if not mode then return end
      if mode:find("Wipe") then
        M.launch(avd, { wipe_data = true })
      elseif mode:find("Quick") then
        M.launch(avd, { cold_boot = false })
      else
        M.launch(avd, { cold_boot = true })
      end
    end)
  end
  if #avds == 1 then
    choose_mode(avds[1])
  else
    vim.ui.select(avds, { prompt = "Pilih AVD:" }, function(avd)
      if avd then choose_mode(avd) end
    end)
  end
end

--- Picker kill: pilih emulator yang jalan → kill.
function M.pick_and_kill()
  local ok, dev = pcall(require, "anvim.devices")
  if not ok then return end
  local running = {}
  for _, d in ipairs(dev.list()) do
    if d.id:match("^emulator%-") then table.insert(running, d.id .. " (" .. d.status .. ")") end
  end
  if #running == 0 then
    alert.info("Tidak ada emulator yang jalan.")
    return
  end
  vim.ui.select(running, { prompt = "Kill emulator:" }, function(choice)
    if choice then
      local id = choice:match("^(%S+)")
      M.kill(id)
    end
  end)
end

return M
