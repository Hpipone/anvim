-- test_tasks.lua

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local function setup()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.getcwd", function() return "/tmp/proj" end)
    mock.raw("fn.isdirectory", function() return 1 end)
    mock.raw("fn.setqflist", function() end)
    mock.raw("fn.jobstart", function(_, opts)
      if opts and opts.on_exit then opts.on_exit(nil, 0) end
      return 5
    end)
    mock.raw("api.nvim_create_buf", function() return 51 end)
    mock.raw("api.nvim_open_win", function() return 52 end)
    mock.raw("api.nvim_buf_is_valid", function() return true end)
    mock.raw("api.nvim_win_is_valid", function() return true end)
    mock.raw("api.nvim_buf_set_lines", function() end)
    mock.raw("api.nvim_buf_line_count", function() return 3 end)
    mock.raw("api.nvim_buf_set_name", function() end)
    mock.raw("uv.new_timer", function() return { start = function() end, stop = function() end, close = function() end } end)
    mock.raw("o.columns", 200)
    mock.raw("o.lines", 50)
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end }
    package.loaded["anvim.devices"] = { get_active = function() return "emulator-5554" end }
    package.loaded["anvim.config"] = { get = function() return { tasks = { timeout_ms = 300000 } } end }
    package.loaded["anvim.util"] = nil
  end

  run("tasks: cmd flutter run pakai -d device", function()
    setup()
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local cmd = t._cmd_for({ type = "flutter", build_tool = "flutter" }, "run")
    assert(cmd[1] == "flutter" and cmd[3] == "-d", table.concat(cmd, " "))
  end)

  run("tasks: gradlew tanpa exec fallback gradle", function()
    setup()
    mock.raw("fn.executable", function(name)
      if name == "gradle" then return 1 end
      return 0
    end)
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local cmd = t._cmd_for({ type = "android", build_tool = "/proj/gradlew" }, "build")
    assert(cmd[1] == "gradle", table.concat(cmd, " "))
  end)

  run("tasks: run sukses on_done(true)", function()
    setup()
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local ok_v
    t.run({ type = "flutter", build_tool = "flutter", root = "/tmp/proj" }, "clean", function(_, ok) ok_v = ok end)
    assert(ok_v == true)
  end)

  run("tasks: tolak jika binary hilang", function()
    setup()
    mock.raw("fn.executable", function() return 0 end)
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local ok_v = nil
    t.run({ type = "flutter", build_tool = "flutter", root = "/tmp/proj" }, "clean", function(_, ok) ok_v = ok end)
    assert(ok_v == false)
  end)

  run("tasks: guard single running + stop", function()
    setup()
    mock.raw("fn.jobstart", function() return 5 end)
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    t.state.running = true
    t.state.current = "run"
    local called = false
    t.run({ type = "flutter", build_tool = "flutter", root = "/tmp" }, "clean", function() called = true end)
    assert(called == false, "harus ditolak saat running")
    t.stop()
    assert(t.state.running == false)
  end)
end
