-- test_dashboard.lua — unit tests for anvim/dashboard.lua
-- ponytail: mock vim.* API, test navigation + close + prereq

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  -- shared mutable alert state
  local alert_state = { warn_called = false, error_called = false }

  local function init_mocks()
    mock.raw("loop.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    mock.raw("loop.now", function() return 10000 end)
    mock.raw("loop.fs_stat", function() return nil end)
    mock.raw("loop.new_timer", function() return { start = function() end, stop = function() end } end)
    mock.raw("fn.executable", function(name) return 1 end)
    mock.raw("fn.exepath", function(name) return "/usr/bin/" .. name end)
    mock.raw("fn.system", function() return "" end)
    mock.raw("fn.expand", function(s) return s:gsub("~", "/home/testuser") end)
    mock.raw("fn.shellescape", function(s) return s end)
    mock.raw("fn.strdisplaywidth", function(s) return #s end)
    mock.raw("fn.has", function() return 0 end)
    mock.raw("fn.strftime", function() return "00:00:00" end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.input", function() return "" end)
    mock.raw("fn.filewritable", function() return 0 end)
    mock.raw("fn.glob", function() return {} end)
    mock.raw("fn.bufwinid", function() return "win_1" end)
    mock.raw("fn.mkdir", function() end)
    mock.raw("fn.jobstart", function() return 1 end)
    mock.raw("api.nvim_create_buf", function() return "buf_1" end)
    mock.raw("api.nvim_open_win", function() return "win_1" end)
    mock.raw("api.nvim_buf_is_valid", function() return true end)
    mock.raw("api.nvim_win_is_valid", function() return true end)
    mock.raw("api.nvim_buf_set_option", function() end)
    mock.raw("api.nvim_buf_set_lines", function() end)
    mock.raw("api.nvim_buf_line_count", function() return 5 end)
    mock.raw("api.nvim_buf_delete", function() end)
    mock.raw("api.nvim_buf_set_name", function() end)
    mock.raw("api.nvim_win_set_cursor", function() end)
    mock.raw("api.nvim_win_close", function() end)
    mock.raw("api.nvim_set_current_win", function() end)
    mock.raw("api.nvim_buf_set_keymap", function() end)
    mock.raw("api.nvim_set_keymap", function() end)
    mock.raw("api.nvim_create_user_command", function() end)
    mock.raw("schedule", function(fn) fn() end)
    mock.raw("o.lines", 50)
    mock.raw("o.columns", 200)
    mock.raw("env.PATH", "/usr/local/bin:/usr/bin:/bin")
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    mock.raw("g.anvim_logcat_max", 5000)
    mock.raw("g.anvim_loader", "lazy")
    mock.raw("g.anvim_loaded", 0)
    mock.raw("g.mapleader", "\\")
    mock.raw("keymap.set", function() end)

    alert_state.warn_called = false
    alert_state.error_called = false

    package.loaded["anvim.status-alert"] = {
      info = function() end,
      warn = function() alert_state.warn_called = true end,
      error = function() alert_state.error_called = true end,
      ok = function() end,
    }
    package.loaded["anvim.health"] = {
      check_configured = function() return {
        tools = {
          adb = { found = true, path = "/usr/bin/adb", label = "ADB" },
          git = { found = true, path = "/usr/bin/git", label = "Git" },
        }
      } end,
      format_line = function(n, r) return r.path or "" end,
    }
    package.loaded["anvim.project"] = {
      detect = function() return { name = "test-project", type = "android" } end,
    }
    package.loaded["anvim.devices"] = {
      list = function() return {
        { id = "emulator-5554", model = "Pixel_6", status = "device" },
      } end,
      get_active = function() return nil end,
      set_active = function() end,
    }
    package.loaded["anvim.tasks"] = { run = function() end }
    package.loaded["anvim.config"] = {
      get = function() return {
        dashboard = { width = 0.85, height = 0.85, border = "single" },
        health_check = { tools = { "adb", "git" } },
      } end,
    }
    package.loaded["anvim.keymaps.dashboard"] = { set = function() end }
    package.loaded["anvim.system_check"] = { interactive = function() end }
    package.loaded["anvim.logcat"] = { open = function() end }
  end

  -- load module once, all tests share
  init_mocks()
  local dash = require("anvim.dashboard")

  run("dashboard: open creates buf + win", function()
    dash.open()
    assert(dash.state.open == true, "open should be true")
    assert(dash.state.buf ~= nil, "buf should be set")
    assert(dash.state.win ~= nil, "win should be set")
  end)

  run("dashboard: nav wraps selected index", function()
    dash.state.open = true
    dash.state.buf = "buf_1"
    dash.state.win = "win_1"
    dash.state.items = {
      { type = "task", label = "a", task = "run", icon = "▶" },
      { type = "task", label = "b", task = "logcat", icon = "■" },
      { type = "task", label = "c", task = "check", icon = "⚡" },
    }
    dash.state.selected = 1
    dash.state.proj = { name = "test", type = "android" }

    dash.nav(-1)
    assert(dash.state.selected == 3, "expected 3, got " .. dash.state.selected)
    dash.nav(1)
    assert(dash.state.selected == 1, "expected 1, got " .. dash.state.selected)
  end)

  run("dashboard: close cleans state", function()
    dash.state.open = true
    dash.state.buf = "buf_1"
    dash.state.win = "win_1"
    dash.close()
    assert(dash.state.open == false)
    assert(dash.state.buf == nil)
    assert(dash.state.win == nil)
  end)

  run("dashboard: do_logcat warns if adb missing", function()
    mock.raw("fn.executable", function(name)
      if name == "adb" then return 0 end
      return 1
    end)
    alert_state.warn_called = false
    dash.state.open = true
    dash.state.buf = "buf_1"
    dash.do_logcat()
    assert(alert_state.warn_called == true, "expected warn when adb missing")
  end)

  run("dashboard: do_check closes and opens system_check", function()
    local system_called = false
    package.loaded["anvim.system_check"] = { interactive = function() system_called = true end }
    dash.state.open = true
    dash.state.buf = "buf_1"
    dash.do_check()
    assert(dash.state.open == false, "dashboard should close")
    assert(system_called, "system_check.interactive should be called")
  end)

  run("dashboard: select task run calls tasks.run", function()
    -- call open() first so lazy_modules captures tasks_m
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    local tasks_called = false
    package.loaded["anvim.tasks"] = { run = function() tasks_called = true end }
    dash.open()
    dash.state.selected = 1
    dash.state.items = {
      { type = "task", label = "Run App", task = "run", icon = "▶" },
    }
    dash.state.proj = { name = "test", type = "android" }
    dash.select()
    assert(tasks_called == true, "tasks.run should be called")
  end)

  run("dashboard: select device calls set_active", function()
    local active_id
    package.loaded["anvim.devices"] = {
      list = function() return {} end,
      get_active = function() return nil end,
      set_active = function(id) active_id = id end,
    }
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    dash.state.selected = 1
    dash.state.items = {
      { type = "device", label = "Pixel_6 (device)", device = { id = "emulator-5554" } },
    }
    dash.state.proj = { name = "test", type = "android" }
    dash.select()
    assert(active_id == "emulator-5554", "set_active should be called with device id, got " .. tostring(active_id))
  end)
end
