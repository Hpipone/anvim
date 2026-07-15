-- anvim: task execution engine
-- ponytail: jobstart + callbacks, no OOP wrapper

local M = {}
M.state = { running = false, current = nil }
local alert = require("anvim.status-alert")

local function cmd_for(project, task_name)
  local t = project.type
  local bt = project.build_tool

  if task_name == "run" then
    if t == "flutter" then return { "flutter", "run" } end
    if bt then return { bt, "installDebug" } end
    return nil
  end
  if task_name == "clean" then
    if t == "flutter" then return { "flutter", "clean" } end
    if bt then return { bt, "clean" } end
    return nil
  end
  if task_name == "build" then
    if t == "flutter" then return { "flutter", "build", "apk" } end
    if bt then return { bt, "assembleDebug" } end
    return nil
  end
  if task_name == "devices" then
    return { "adb", "devices", "-l" }
  end
  return nil
end

--- Run a task by name. Calls on_done(output, success) on completion.
function M.run(project, task_name, on_done)
  local ok, err = pcall(function()
    if not project then
      alert.error("tasks", "project nil")
      return
    end
    if M.state.running then
      alert.warn("Task already running: " .. M.state.current)
      return
    end

    local cmd = cmd_for(project, task_name)
    if not cmd then
      if project.type == "unknown" then
        alert.warn("Buka project Android (build.gradle) atau Flutter (pubspec.yaml) dulu.\nTask kaya build/clean/run cuma jalan di project yang terdeteksi.")
      else
        alert.warn("Task '" .. task_name .. "' gak didukung buat project " .. project.type .. ".\nCoba pake task lain dari dashboard.")
      end
      return
    end

    M.state.running = true
    M.state.current = task_name
    alert.info("Running: " .. table.concat(cmd, " "))

    local out_lines = {}
    vim.fn.jobstart(cmd, {
      cwd = vim.fn.getcwd(),
      stdout_buffered = false,
      on_stdout = function(_, data)
        if data then
          for _, l in ipairs(data) do
            if l ~= "" then table.insert(out_lines, l) end
          end
        end
      end,
      on_stderr = function(_, data)
        if data then
          for _, l in ipairs(data) do
            if l ~= "" then table.insert(out_lines, l) end
          end
        end
      end,
      on_exit = function(_, code)
        M.state.running = false
        M.state.current = nil
        local output = table.concat(out_lines, "\n")
        local ok = code == 0
        if ok then
          alert.info("Task completed: " .. task_name)
        else
          alert.error("task", "Task failed (code " .. code .. "): " .. task_name)
        end
        if on_done then on_done(output, ok, task_name) end
      end,
    })
  end)
  if not ok then
    alert.error("tasks run", err)
  end
end

return M
