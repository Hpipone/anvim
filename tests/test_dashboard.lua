-- test_dashboard.lua — unit tests for anvim/dashboard.lua
-- ponytail: mock vim.* API, test navigation + close + prereq

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local function setup_mock()
    local bufs, wins = {}, {}
    local buf_counter, win_counter = 0, 0
    local schedule_calls = {}
    local executable_results = {}

    mock.raw("fn.executable", function(name)
      if executable_results[name] ~= nil then return executable_results[name] end
      return 1
    end)
    mock.raw("fn.exepath", function(name) return name end)
    mock.raw("fn.system", function() return "" end)
    mock.raw("fn.expand", function(s) return s:gsub("~", "/home/testuser") end)
    mock.raw("fn.shellescape", function(s) return s end)
    mock.raw("fn.strdisplaywidth", function(s) return #s end)
    mock.raw("fn.has", function() return 0 end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.input", function() return "" end)
    mock.raw("fn.filewritable", function() return 0 end)
    mock.raw("fn.glob", function() return {} end)
    mock.raw("fn.bufwinid", function() return "win_1" end)
    mock.raw("api.nvim_create_buf", function(_, _)
      buf_counter = buf_counter + 1
      local id = "buf_" .. buf_counter
      bufs[id] = { lines = {}, opts = {} }
      return id
    end)
    mock.raw("api.nvim_open_win", function(_, _, _)
      win_counter = win_counter + 1
      local id = "win_" .. win_counter
      wins[id] = {}
      return id
    end)
    mock.raw("api.nvim_buf_is_valid", function() return true end)
    mock.raw("api.nvim_win_is_valid", function() return true end)
    mock.raw("api.nvim_buf_set_option", function(buf, opt, val)
      if bufs[buf] then bufs[buf].opts[opt] = val end
    end)
    mock.raw("api.nvim_buf_set_lines", function(buf, ...) if bufs[buf] then bufs[buf].lines = {...} end end)
    mock.raw("api.nvim_buf_line_count", function() return 5 end)
    mock.raw("api.nvim_buf_delete", function() end)
    mock.raw("api.nvim_buf_set_name", function() end)
    mock.raw("api.nvim_win_set_cursor", function() end)
    mock.raw("api.nvim_win_close", function() end)
    mock.raw("api.nvim_set_current_win", function() end)
    mock.raw("api.nvim_buf_set_keymap", function() end)
    mock.raw("api.nvim_create_user_command", function() end)
    mock.raw("schedule", function(fn) table.insert(schedule_calls, fn) end)
    mock.raw("loop.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    mock.raw("loop.now", function() return 10000 end)
    mock.raw("loop.fs_stat", function() return nil end)
    mock.raw("o.lines", 50)
    mock.raw("o.columns", 200)
    mock.raw("env.PATH", "/usr/local/bin:/usr/bin:/bin")
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    mock.raw("g.anvim_logcat_max", 5000)
    mock.raw("g.anvim_loader", "lazy")
    mock.raw("g.anvim_loaded", 0)
    mock.raw("g.mapleader", "\\")
    mock.raw("bo", {})
    mock.raw("wo", {})

    return {
      schedule_calls = schedule_calls,
      set_exec = function(name, val) executable_results[name] = val end,
    }
  end

  run("dashboard: open creates buf + win", function()
    local env = setup_mock()
    package.loaded["anvim.health"] = {
      check_configured = function() return { tools = {} } end,
      format_line = function() return "" end,
    }
    package.loaded["anvim.project"] = {
      detect = function() return { name = "test", type = "android" } end,
    }
    package.loaded["anvim.devices"] = {
      list = function() return {} end,
      get_active = function() return nil end,
      set_active = function() end,
    }
    package.loaded["anvim.tasks"] = { run = function() end }
    package.loaded["anvim.config"] = {
      get = function() return {
        dashboard = { width = 0.85, height = 0.85, border = "single" },
        health_check = { tools = {} },
      } end,
    }
    package.loaded["anvim.keymaps.dashboard"] = { set = function() end }
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end }

    local dash = require("anvim.dashboard")
    dash.open()
    assert(dash.state.open == true)
    assert(dash.state.buf ~= nil)
    assert(dash.state.win ~= nil)
  end)

  run("dashboard: nav wraps selected index", function()
    local env = setup_mock()
    package.loaded["anvim.health"] = {
      check_configured = function() return { tools = {} } end,
      format_line = function() return "" end,
    }
    package.loaded["anvim.project"] = {
      detect = function() return { name = "test", type = "android" } end,
    }
    package.loaded["anvim.devices"] = {
      list = function() return {} end,
      get_active = function() return nil end,
      set_active = function() end,
    }
    package.loaded["anvim.tasks"] = { run = function() end }
    package.loaded["anvim.config"] = {
      get = function() return {
        dashboard = { width = 0.85, height = 0.85, border = "single" },
        health_check = { tools = {} },
      } end,
    }
    package.loaded["anvim.keymaps.dashboard"] = { set = function() end }
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end }

    local dash = require("anvim.dashboard")
    dash.state.open = true
    dash.state.buf = "buf_1"
    dash.state.win = "win_1"
    dash.state.items = { { type = "task", label = "a" }, { type = "task", label = "b" }, { type = "task", label = "c" } }
    dash.state.selected = 1
    dash.state.proj = { name = "test", type = "android" }

    dash.nav(-1)  -- wrap to end
    assert(dash.state.selected == 3, "expected 3, got " .. dash.state.selected)

    dash.nav(1)   -- back to 1
    assert(dash.state.selected == 1, "expected 1, got " .. dash.state.selected)
  end)

  run("dashboard: close cleans state", function()
    local env = setup_mock()
    local dash = require("anvim.dashboard")
    dash.state.open = true
    dash.state.buf = "buf_1"
    dash.state.win = "win_1"
    dash.close()
    assert(dash.state.open == false)
    assert(dash.state.buf == nil)
    assert(dash.state.win == nil)
  end)

  run("dashboard: do_logcat warns if adb missing", function()
    local env = setup_mock()
    env.set_exec("adb", 0)
    local warned = false
    package.loaded["anvim.status-alert"] = {
      info = function() end,
      warn = function() warned = true; end,
      error = function() end,
      ok = function() end,
    }
    package.loaded["anvim.logcat"] = { open = function() end }

    local dash = require("anvim.dashboard")
    dash.do_logcat()
    assert(warned == true, "expected warn when adb missing")
  end)

  run("dashboard: do_check closes and opens system_check", function()
    local env = setup_mock()
    local system_called = false
    package.loaded["anvim.status-alert"] = {
      info = function() end, warn = function() end, error = function() end, ok = function() end,
    }
    package.loaded["anvim.system_check"] = { interactive = function() system_called = true end }

    local dash = require("anvim.dashboard")
    dash.state.open = true
    dash.state.buf = "buf_1"
    dash.do_check()
    assert(dash.state.open == false, "dashboard should close")
    assert(system_called, "system_check.interactive should be called")
  end)
end
