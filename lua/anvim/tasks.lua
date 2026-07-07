-- anvim: task execution engine
-- ponytail: jobstart + callbacks, no OOP wrapper

local M = {}
M.state = { running = false, current = nil }

local function cmd_for(project, task_name)
  local t = project.type
  local bt = project.build_tool

  if task_name == "run" then
    if t == "flutter" then return { "flutter", "run" } end
    return { bt, "installDebug" }
  end
  if task_name == "clean" then
    if t == "flutter" then return { "flutter", "clean" } end
    return { bt, "clean" }
  end
  if task_name == "build" then
    if t == "flutter" then return { "flutter", "build", "apk" } end
    return { bt, "assembleDebug" }
  end
  if task_name == "devices" then
    return { "adb", "devices", "-l" }
  end
  return nil
end

--- Run a task by name. Calls on_done(output, success) on completion.
function M.run(project, task_name, on_done)
  if M.state.running then
    vim.notify("[anvim] Task already running: " .. M.state.current, vim.log.levels.WARN)
    return
  end

  local cmd = cmd_for(project, task_name)
  if not cmd then
    vim.notify("[anvim] Unknown task: " .. task_name, vim.log.levels.ERROR)
    return
  end

  M.state.running = true
  M.state.current = task_name
  vim.notify("[anvim] Running: " .. table.concat(cmd, " "), vim.log.levels.INFO)

  local out_lines = {}
  vim.fn.jobstart(cmd, {
    cwd = vim.fn.getcwd(),
    stdout_buffered = true,
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
        vim.notify("[anvim] Task completed: " .. task_name, vim.log.levels.INFO)
      else
        vim.notify("[anvim] Task failed (code " .. code .. "): " .. task_name, vim.log.levels.ERROR)
      end
      if on_done then
        on_done(output, ok, task_name)
      end
    end,
  })
end

--- Run a shell command and display output in a scratch buffer.
function M.run_in_term(cmd_str)
  vim.cmd("belowright split | term " .. cmd_str)
  vim.cmd("startinsert!")
end

return M
