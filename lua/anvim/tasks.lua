-- anvim: task execution engine — timeout, device -s, split output + quickfix

local M = {}
M.state = { running = false, current = nil, job_id = nil, buf = nil, win = nil, gen = 0, last = nil }
local alert = require("anvim.status-alert")
local util = require("anvim.util")

local function cfg_tasks()
  local ok, c = pcall(function() return require("anvim.config").get() end)
  local t = ok and c and c.tasks or {}
  return { timeout_ms = t.timeout_ms or 300000 }
end

local function device_prefix()
  local ok, dev = pcall(require, "anvim.devices")
  if ok and dev and dev.get_active then
    local id = dev.get_active()
    if id and id ~= "" then return { "-s", id } end
  end
  return {}
end

--- adb absolut untuk launch (PATH nvim bisa beda dari terminal).
local function adb_bin()
  local ok, sys = pcall(require, "anvim.system_check")
  if ok and sys.adb_bin then
    local p = sys.adb_bin()
    if p and p ~= "" then return p end
  end
  return "adb"
end

--- Launch app android yang baru di-install via monkey.
--- Gagal launch TIDAK menggagalkan install (status terpisah).
local function launch_android(package, device_id)
  if not package or package == "" then
    alert.info("Installed — package id unknown, launch manually.")
    return
  end
  local cmd = { adb_bin() }
  if device_id and device_id ~= "" then
    vim.list_extend(cmd, { "-s", device_id })
  end
  vim.list_extend(cmd, { "shell", "monkey", "-p", package, "-c", "android.intent.category.LAUNCHER", "1" })
  alert.info("Launching " .. package .. " ...")
  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code == 0 then
        alert.ok("App launched on " .. (device_id or "device"))
      else
        alert.warn("Install OK, launch failed (code " .. tostring(code) .. ") — open manually.")
      end
    end,
  })
end

--- Snapshot ringan project untuk rerun (stabil walau user pindah dir).
local function snapshot_project(project)
  if type(project) ~= "table" then return nil end
  return {
    type = project.type,
    name = project.name,
    root = project.root,
    branch = project.branch,
    build_tool = project.build_tool,
    package = project.package,
    version = project.version,
    scripts = project.scripts,
  }
end

--- adb id belum tentu dikenal flutter (namespace beda). Validasi silang:
--- tak dikenal → warn + tetap jalan (biar error flutter yang bicara).
local function validated_flutter_id(id)
  local ok, fl = pcall(require, "anvim.flutter")
  if not ok or not fl.list then return id end
  local ok2, devs = pcall(fl.list)
  if not ok2 or not devs then return id end
  for _, d in ipairs(devs) do
    if d.id == id then return id end
  end
  alert.warn("Device " .. id .. " is not in `flutter devices` — trying anyway, may fail.")
  return id
end

local function cmd_for(project, task_name)
  local t = project.type
  local bt = project.build_tool

  if task_name == "run" then
    if t == "node" then
      local s = project.scripts or {}
      if s.dev then return { "npm", "run", "dev" } end
      if s.start then return { "npm", "start" } end
      return nil
    end
    if t == "flutter" then
      local pre = device_prefix()
      local c = { "flutter", "run" }
      for _, a in ipairs(pre) do table.insert(c, 2, a) end
      -- flutter pakai -d (namespace bisa beda dari adb id → validasi silang)
      if #pre == 2 then return { "flutter", "run", "-d", validated_flutter_id(pre[2]) } end
      return c
    end
    if bt then
      if bt:match("gradlew") and vim.fn.executable(bt) ~= 1 and vim.fn.executable("gradle") == 1 then
        return { "gradle", "installDebug" }
      end
      return { bt, "installDebug" }
    end
    return nil
  end
  if task_name == "clean" then
    if t == "node" then
      if (project.scripts or {}).clean then return { "npm", "run", "clean" } end
      return nil
    end
    if t == "flutter" then return { "flutter", "clean" } end
    if bt then
      if bt:match("gradlew") and vim.fn.executable(bt) ~= 1 and vim.fn.executable("gradle") == 1 then
        return { "gradle", "clean" }
      end
      return { bt, "clean" }
    end
    return nil
  end
  if task_name == "build" then
    if t == "node" then
      if (project.scripts or {}).build then return { "npm", "run", "build" } end
      return nil
    end
    if t == "flutter" then return { "flutter", "build", "apk" } end
    if bt then
      if bt:match("gradlew") and vim.fn.executable(bt) ~= 1 and vim.fn.executable("gradle") == 1 then
        return { "gradle", "assembleDebug" }
      end
      return { bt, "assembleDebug" }
    end
    return nil
  end
  if task_name == "test" then
    if t == "node" then
      if (project.scripts or {}).test then return { "npm", "test" } end
      return nil
    end
    if t == "flutter" then return { "flutter", "test" } end
    if bt then
      if bt:match("gradlew") and vim.fn.executable(bt) ~= 1 and vim.fn.executable("gradle") == 1 then
        return { "gradle", "test" }
      end
      return { bt, "test" }
    end
    return nil
  end
  if task_name == "devices" then
    local adb_bin = "adb"
    pcall(function()
      local p = require("anvim.system_check").adb_bin()
      if p and p ~= "" then adb_bin = p end
    end)
    return { adb_bin, "devices", "-l" }
  end
  return nil
end

M._cmd_for = cmd_for

local function ensure_output_win()
  local buf = M.state.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    M.state.buf = buf
    pcall(vim.api.nvim_buf_set_name, buf, "anvim://task-output")
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].filetype = "anvim-task"
    -- window output bisa ditutup user (q): buffer + history job tetap ada
    pcall(vim.keymap.set, "n", "q", function() M.close_output() end,
      { buffer = buf, nowait = true, silent = true, desc = "Close task output" })
    pcall(vim.keymap.set, "n", "<Esc>", function() M.close_output() end,
      { buffer = buf, nowait = true, silent = true, desc = "Close task output" })
  end
  local win = M.state.win
  if not (win and vim.api.nvim_win_is_valid(win)) then
    local cols = vim.o.columns or 80
    local lines = vim.o.lines or 24
    local h = math.floor(lines * 0.3)
    win = vim.api.nvim_open_win(buf, true, {
      relative = "editor", width = cols - 2, height = math.max(8, h),
      col = 1, row = lines - h - 1, style = "minimal", border = "rounded",
      title = " anvim task (q to close) ", title_pos = "center",
      zindex = 60, -- selalu di depan dashboard
    })
    M.state.win = win
  end
  return buf, win
end

--- Tutup window output (buffer dipertahankan; run berikutnya pakai lagi).
--- Tidak stop job yang jalan — pakai x di dashboard / tasks.stop().
--- Seperti check/logcat: keluar → kembali ke dashboard.
function M.close_output()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    pcall(vim.api.nvim_win_close, M.state.win, true)
  end
  M.state.win = nil
  vim.schedule(function()
    local ok, dash = pcall(require, "anvim.dashboard")
    if ok and not dash.state.open then
      pcall(dash.open)
    end
  end)
end

local function append_output(buf, data)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
  local lines = {}
  for _, l in ipairs(data or {}) do
    if l ~= "" then table.insert(lines, l) end
  end
  if #lines == 0 then return end
  pcall(function()
    vim.bo[buf].modifiable = true
    local last = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, last, last, false, lines)
    vim.bo[buf].modifiable = false
  end)
end

function M.stop()
  M.state.gen = (M.state.gen or 0) + 1
  if M.state.job_id then
    pcall(vim.fn.jobstop, M.state.job_id)
    M.state.job_id = nil
  end
  M.state.running = false
  M.state.current = nil
end

--- Inti eksekusi: dipakai run() dan run_custom(). label untuk judul/output.
--- env opsional diteruskan ke job (mis. ANDROID_SERIAL untuk gradle).
local function run_cmd(cmd, label, cwd, on_done, env)
  if M.state.running then
    alert.warn("Task already running: " .. tostring(M.state.current) .. " (x to cancel)")
    return
  end

  M.state.gen = (M.state.gen or 0) + 1
  local my_gen = M.state.gen
  M.state.running = true
  M.state.current = label
  alert.info("Running: " .. table.concat(cmd, " "))

  local buf = ensure_output_win()
  append_output(buf, { "", "$ " .. table.concat(cmd, " ") })

  local out_lines = {}
  if not cwd or cwd == "" or vim.fn.isdirectory(cwd) ~= 1 then cwd = vim.fn.getcwd() end

  local t = cfg_tasks()
  local timed_out = false
  local timer = nil
  if t.timeout_ms and t.timeout_ms > 0 then
    timer = vim.uv.new_timer()
    timer:start(t.timeout_ms, 0, vim.schedule_wrap(function()
      if my_gen ~= M.state.gen then return end
      if M.state.running and M.state.current == label then
        timed_out = true
        M.stop()
        append_output(buf, { "[timeout " .. tostring(t.timeout_ms) .. "ms — task di-cancel]" })
        alert.error("task", "Timeout: " .. label)
        if on_done then on_done(table.concat(out_lines, "\n"), false) end
      end
    end))
  end

  local job_id = vim.fn.jobstart(cmd, {
    cwd = cwd,
    env = env,
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      if data then
        for _, l in ipairs(data) do
          if l ~= "" then table.insert(out_lines, l) end
        end
        vim.schedule(function() append_output(M.state.buf, data) end)
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, l in ipairs(data) do
          if l ~= "" then table.insert(out_lines, l) end
        end
        vim.schedule(function() append_output(M.state.buf, data) end)
      end
    end,
      on_exit = function(_, code)
        if timer then pcall(function() timer:stop() end) pcall(function() timer:close() end) end
        if timed_out then return end
        if my_gen ~= M.state.gen then return end -- dibatalkan/diganti: abaikan
        M.state.running = false
      M.state.current = nil
      M.state.job_id = nil
      local output = table.concat(out_lines, "\n")
      local success = code == 0
      -- quickfix tetap terisi; sinyal selesai = notify (tanpa log done)
      pcall(vim.fn.setqflist, {}, " ", { title = "anvim:" .. label, lines = out_lines })
      if success then
        alert.ok("Task completed: " .. label)
      else
        alert.error("task", "Task failed (code " .. tostring(code) .. "): " .. label)
      end
      if on_done then on_done(output, success, label) end
    end,
  })
  if job_id == nil or job_id <= 0 then
    if timer then pcall(function() timer:stop() end) pcall(function() timer:close() end) end
    M.state.running = false
    M.state.current = nil
    alert.error("task", "jobstart failed for " .. table.concat(cmd, " "))
    if on_done then on_done("", false) end
  else
    M.state.job_id = job_id
  end
end

--- Run a task by name. Calls on_done(output, success) on completion.
function M.run(project, task_name, on_done)
  local ok, err = pcall(function()
    if not project then
      alert.error("tasks", "project nil")
      if on_done then on_done("", false) end
      return
    end

    local cmd = cmd_for(project, task_name)
    if not cmd then
      if project.type == "unknown" then
        alert.warn("Open an Android, Flutter, or Node project first.")
      else
        alert.warn("Task '" .. task_name .. "' is not supported for project " .. project.type .. ".")
      end
      if on_done then on_done("", false) end
      return
    end

    if vim.fn.executable(cmd[1]) == 0 and not cmd[1]:find("/") then
      alert.error("task", cmd[1] .. " not found in PATH. Run :AnvimCheck.")
      if on_done then on_done("", false) end
      return
    end

    local cwd = (project.root and project.root ~= "") and project.root or util.project_root()
    -- gradle tidak kenal -s: teruskan device via ANDROID_SERIAL
    local env = nil
    if project.type == "android" then
      local ok_d, dev = pcall(require, "anvim.devices")
      if ok_d and dev.get_active then
        local id = dev.get_active()
        if id and id ~= "" then env = { ANDROID_SERIAL = id } end
      end
    end
    -- gradlew tidak executable → coba chmod +x sekali, fallback gradle
    if cmd[1]:match("gradlew$") and vim.fn.executable(cmd[1]) ~= 1 then
      pcall(vim.fn.system, "chmod +x " .. util.esc(cmd[1]) .. " 2>/dev/null")
      if vim.fn.executable(cmd[1]) ~= 1 and vim.fn.executable("gradle") == 1 then
        alert.warn("gradlew not executable — using gradle from PATH.")
        cmd = { "gradle", cmd[2] }
      end
    end
    M.state.last = {
      kind = "named",
      task = task_name,
      project = snapshot_project(project),
    }
    -- run android sukses → auto-launch di device (install saja tak cukup)
    if task_name == "run" and project.type == "android" then
      local wrapped = on_done
      local dev_id = env and env.ANDROID_SERIAL or nil
      local pkg = project.package
      on_done = function(output, ok_run, label)
        if ok_run then
          launch_android(pkg, dev_id)
        end
        if wrapped then wrapped(output, ok_run, label) end
      end
    end
    run_cmd(cmd, task_name, cwd, on_done, env)
  end)
  if not ok then
    M.state.running = false
    alert.error("tasks run", err)
    if on_done then on_done("", false) end
  end
end

--- Run custom command user: cmd = {"prog","arg"...}, label untuk judul.
function M.run_custom(cmd, label, on_done)
  label = label or (type(cmd) == "table" and table.concat(cmd, " ") or "custom")
  local ok, err = pcall(function()
    if type(cmd) ~= "table" or #cmd == 0 or type(cmd[1]) ~= "string" then
      alert.error("task", "invalid custom cmd (must be a string list).")
      if on_done then on_done("", false) end
      return
    end
    if vim.fn.executable(cmd[1]) == 0 and not cmd[1]:find("/") then
      alert.error("task", cmd[1] .. " not found in PATH. Run :AnvimCheck.")
      if on_done then on_done("", false) end
      return
    end
    M.state.last = { kind = "custom", cmd = cmd, label = label }
    run_cmd(cmd, label, util.project_root(), on_done)
  end)
  if not ok then
    M.state.running = false
    alert.error("tasks custom", err)
    if on_done then on_done("", false) end
  end
end

--- Ulangi task terakhir (named maupun custom) memakai snapshot saat run.
--- Named tidak re-detect agar root stabil; warn bila cwd sudah pindah.
--- Return false jika belum ada / tidak bisa jalan.
function M.rerun(on_done)
  local last = M.state.last
  if not last then
    alert.warn("No task has been run yet.")
    return false
  end
  if last.kind == "custom" then
    M.run_custom(last.cmd, last.label, on_done)
    return true
  end
  local proj = last.project
  if not proj or proj.type == "unknown" then
    alert.warn("Open Android, Flutter, or Node project first.")
    return false
  end
  local cwd_ok, cwd = pcall(vim.fn.getcwd)
  if cwd_ok and cwd and proj.root and cwd ~= proj.root then
    alert.warn("Rerun uses project snapshot " .. tostring(proj.root) .. " (cwd is now " .. cwd .. ").")
  end
  M.run(proj, last.task, on_done)
  return true
end

return M
