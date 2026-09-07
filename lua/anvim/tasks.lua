-- anvim: task execution engine — timeout, device -s, split output + quickfix

local M = {}
M.state = { running = false, current = nil, job_id = nil, buf = nil, win = nil }
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

local function cmd_for(project, task_name)
  local t = project.type
  local bt = project.build_tool

  if task_name == "run" then
    if t == "flutter" then
      local pre = device_prefix()
      local c = { "flutter", "run" }
      for _, a in ipairs(pre) do table.insert(c, 2, a) end
      -- flutter run -d <id>: prefix adalah -s? flutter pakai -d. koreksi:
      if #pre == 2 then return { "flutter", "run", "-d", pre[2] } end
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
    return { "adb", "devices", "-l" }
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
  end
  local win = M.state.win
  if not (win and vim.api.nvim_win_is_valid(win)) then
    local cols = vim.o.columns or 80
    local lines = vim.o.lines or 24
    local h = math.floor(lines * 0.3)
    win = vim.api.nvim_open_win(buf, false, {
      relative = "editor", width = cols - 2, height = math.max(8, h),
      col = 1, row = lines - h - 1, style = "minimal", border = "rounded",
      title = " anvim task ", title_pos = "center",
    })
    M.state.win = win
  end
  return buf, win
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
  if M.state.job_id then
    pcall(vim.fn.jobstop, M.state.job_id)
    M.state.job_id = nil
  end
  M.state.running = false
  M.state.current = nil
end

--- Inti eksekusi: dipakai run() dan run_custom(). label untuk judul/output.
local function run_cmd(cmd, label, cwd, on_done)
  if M.state.running then
    alert.warn("Task already running: " .. tostring(M.state.current) .. " (x untuk cancel)")
    return
  end

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
      M.state.running = false
      M.state.current = nil
      M.state.job_id = nil
      local output = table.concat(out_lines, "\n")
      local success = code == 0
      pcall(vim.fn.setqflist, {}, " ", { title = "anvim:" .. label, lines = out_lines })
      if success then
        append_output(M.state.buf, { "[✓ done: " .. label .. "]" })
        alert.ok("Task completed: " .. label)
      else
        append_output(M.state.buf, { "[✗ failed (" .. tostring(code) .. "): " .. label .. " — :copen untuk detail]" })
        alert.error("task", "Task failed (code " .. tostring(code) .. "): " .. label)
      end
      if on_done then on_done(output, success, label) end
    end,
  })
  if job_id == nil or job_id <= 0 then
    if timer then pcall(function() timer:stop() end) pcall(function() timer:close() end) end
    M.state.running = false
    M.state.current = nil
    alert.error("task", "jobstart gagal untuk " .. table.concat(cmd, " "))
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
        alert.warn("Buka project Android (build.gradle) atau Flutter (pubspec.yaml) dulu.")
      else
        alert.warn("Task '" .. task_name .. "' gak didukung buat project " .. project.type .. ".")
      end
      if on_done then on_done("", false) end
      return
    end

    if vim.fn.executable(cmd[1]) == 0 and not cmd[1]:find("/") then
      alert.error("task", cmd[1] .. " tidak ditemukan di PATH. Jalankan :AnvimCheck.")
      if on_done then on_done("", false) end
      return
    end

    local cwd = (project.root and project.root ~= "") and project.root or util.project_root()
    -- gradlew tidak executable → coba chmod +x sekali, fallback gradle
    if cmd[1]:match("gradlew$") and vim.fn.executable(cmd[1]) ~= 1 then
      pcall(vim.fn.system, "chmod +x " .. util.esc(cmd[1]) .. " 2>/dev/null")
      if vim.fn.executable(cmd[1]) ~= 1 and vim.fn.executable("gradle") == 1 then
        alert.warn("gradlew tidak executable — pakai gradle PATH.")
        cmd = { "gradle", cmd[2] }
      end
    end
    M.state.last = { kind = "named", task = task_name }
    run_cmd(cmd, task_name, cwd, on_done)
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
      alert.error("task", "custom cmd tidak valid (harus list string).")
      if on_done then on_done("", false) end
      return
    end
    if vim.fn.executable(cmd[1]) == 0 and not cmd[1]:find("/") then
      alert.error("task", cmd[1] .. " tidak ditemukan di PATH. Jalankan :AnvimCheck.")
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

--- Ulangi task terakhir (named maupun custom). Return false jika belum ada.
function M.rerun(on_done)
  local last = M.state.last
  if not last then
    alert.warn("Belum ada task yang dijalankan.")
    return false
  end
  if last.kind == "custom" then
    M.run_custom(last.cmd, last.label, on_done)
    return true
  end
  local ok, proj = pcall(function() return require("anvim.project").detect() end)
  if not ok or not proj or proj.type == "unknown" then
    alert.warn("Open Android or Flutter project first.")
    return false
  end
  M.run(proj, last.task, on_done)
  return true
end

return M
