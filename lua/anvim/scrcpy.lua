-- anvim: scrcpy — mirror + kontrol HP, pengganti emulator manager.
-- Binary jalan dari ~/.anvim/tools (no_deploy): selalu pakai absolute path,
-- tanpa mengotori PATH. Butuh adb + device status "device".

local M = {}
M.jobs = {} -- device_id -> job_id yang sedang mirror
local alert = require("anvim.status-alert")
local util = require("anvim.util")
local OS = util.OS

--- Cari binary scrcpy: PATH → tools-dir (no_deploy) → local/bin.
function M.find_binary()
  local bin = OS == "windows" and "scrcpy.exe" or "scrcpy"
  local exe = vim.fn.exepath(bin)
  if exe and exe ~= "" then return exe end
  local tools = vim.fn.glob(vim.fn.expand("~") .. "/.anvim/tools/scrcpy/**/" .. bin, false, true)
  for _, p in ipairs(tools) do
    if vim.fn.executable(p) == 1 then return p end
  end
  local lb = util.local_bin() .. (OS == "windows" and "\\" or "/") .. bin
  if vim.fn.executable(lb) == 1 then return lb end
  return nil
end

--- Susun argv scrcpy: polos `-s <id>` + extra user. Tanpa flag bawaan.
function M.build_cmd(device_id, opts)
  opts = opts or {}
  local bin = M.find_binary() or (OS == "windows" and "scrcpy.exe" or "scrcpy")
  local cmd = { bin, "-s", device_id }
  for _, a in ipairs(opts.extra or {}) do table.insert(cmd, a) end
  return cmd
end

function M.is_running(device_id)
  local job = M.jobs[device_id]
  return job ~= nil
end

local function valid_device(device_id)
  if not device_id or device_id == "" then return false end
  local ok, dev = pcall(require, "anvim.devices")
  if not ok then return true end
  for _, d in ipairs(dev.list()) do
    if d.id == device_id then
      if d.status ~= "device" then
        alert.warn("Device " .. device_id .. " status " .. d.status .. " — scrcpy may fail.")
      end
      return true
    end
  end
  alert.warn("Device " .. device_id .. " not connected.")
  return false
end

--- Mirror device. on_done(ok). Menutup nvim ikut mematikan mirror (job anak).
function M.launch(device_id, opts, on_done)
  on_done = on_done or function() end
  opts = opts or {}
  if M.jobs[device_id] then
    alert.info("Scrcpy already running for " .. device_id)
    on_done(true)
    return
  end
  if not M.find_binary() then
    alert.warn("Scrcpy not installed — open :AnvimCheck to install.")
    vim.schedule(function()
      local ok, sys = pcall(require, "anvim.system_check")
      if ok then sys.interactive() end
    end)
    on_done(false)
    return
  end
  if not valid_device(device_id) then
    on_done(false)
    return
  end
  local cmd = M.build_cmd(device_id, opts)
  alert.info("Scrcpy: " .. device_id)
  local job = vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      M.jobs[device_id] = nil
      if code ~= 0 then
        alert.warn("Scrcpy stopped (code " .. tostring(code) .. "): " .. device_id)
      else
        alert.info("Scrcpy stopped: " .. device_id)
      end
      on_done(code == 0)
    end,
  })
  if job == nil or job <= 0 then
    alert.error("scrcpy", "jobstart failed: " .. table.concat(cmd, " "))
    on_done(false)
    return
  end
  M.jobs[device_id] = job
end

--- Hentikan mirror: jobstop + pkill fallback (posix).
function M.stop(device_id, on_done)
  on_done = on_done or function() end
  local job = M.jobs[device_id]
  if job then
    pcall(vim.fn.jobstop, job)
    M.jobs[device_id] = nil
  end
  if OS ~= "windows" then
    pcall(vim.fn.system, "pkill -f " .. util.esc("scrcpy.*" .. device_id) .. " 2>/dev/null")
  end
  alert.info("Scrcpy stopped: " .. tostring(device_id))
  on_done(true)
end

--- Ambil device id dari label picker ("○ scrcpy  ID (model)").
function M._id_from_label(label)
  if not label then return nil end
  return label:match("%s%s(%S+)")
end

--- Picker: pilih device → scrcpy langsung (stop bila jalan). Tanpa record.
function M.pick()
  local ok, dev = pcall(require, "anvim.devices")
  if not ok then return end
  local list = {}
  for _, d in ipairs(dev.list()) do
    if d.status == "device" then table.insert(list, d) end
  end
  if #list == 0 then
    alert.warn("No online devices for scrcpy.")
    return
  end
  if #list == 1 and not M.jobs[list[1].id] then
    M.launch(list[1].id, {})
    return
  end
  local labels = {}
  for _, d in ipairs(list) do
    local st = M.jobs[d.id] and "● scrcpy on" or "○ scrcpy"
    table.insert(labels, st .. "  " .. d.id .. " (" .. (d.model or "?") .. ")")
  end
  vim.ui.select(labels, { prompt = "Scrcpy device:" }, function(choice)
    if not choice then return end
    local id = M._id_from_label(choice)
    if not id then return end
    if M.jobs[id] then
      M.stop(id)
      return
    end
    M.launch(id, {})
  end)
end

return M
