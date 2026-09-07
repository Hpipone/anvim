-- test_logcat.lua — filter benar, history trim, no-dashboard default

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local alert_state = { warn_called = false }

  local function init_mocks()
    mock.raw("fn.executable", function(name)
      if name == "adb" then return 1 end
      return 0
    end)
    mock.raw("fn.system", function() return "" end)
    mock.raw("fn.shellescape", function(s) return "'" .. s .. "'" end)
    mock.raw("fn.expand", function(s) return (s:gsub("~", "/home/testuser")) end)
    mock.raw("fn.jobstart", function() return 1 end)
    mock.raw("api.nvim_create_buf", function() return 31 end)
    mock.raw("api.nvim_open_win", function() return 32 end)
    mock.raw("api.nvim_buf_is_valid", function() return true end)
    mock.raw("api.nvim_win_is_valid", function() return true end)
    mock.raw("api.nvim_set_current_win", function() end)
    mock.raw("api.nvim_buf_set_lines", function() end)
    mock.raw("api.nvim_buf_line_count", function() return 5 end)
    mock.raw("api.nvim_buf_delete", function() end)
    mock.raw("api.nvim_buf_set_name", function() end)
    mock.raw("api.nvim_win_close", function() end)
    mock.raw("keymap.set", function() end)
    mock.raw("schedule", function(fn) fn() end)
    mock.raw("uv.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    mock.raw("o.lines", 50)
    mock.raw("o.columns", 200)
    mock.raw("env.PATH", "/usr/local/bin:/usr/bin:/bin")
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })

    alert_state.warn_called = false

    package.loaded["anvim.status-alert"] = {
      info = function() end,
      warn = function() alert_state.warn_called = true end,
      error = function() end,
      ok = function() end,
    }
    package.loaded["anvim.dashboard"] = { open = function() end }
    package.loaded["anvim.devices"] = { get_active = function() return nil end }
    package.loaded["anvim.config"] = {
      get = function()
        return { logcat = { max_lines = 5, filter_default = "I", no_dashboard_on_close = true } }
      end,
    }
  end

  init_mocks()
  package.loaded["anvim.logcat"] = nil
  local lc = require("anvim.logcat")

  run("logcat: build_cmd tanpa -s tag salah", function()
    local cmd = lc._build_cmd("E")
    local joined = table.concat(cmd, " ")
    assert(joined:find("%*:E"), "harus ada *:E, got " .. joined)
    assert(not joined:find("%-s INFO"), "tidak boleh ada -s INFO, got " .. joined)
  end)

  run("logcat: build_cmd pakai -s device jika active", function()
    package.loaded["anvim.devices"] = { get_active = function() return "emulator-5554" end }
    package.loaded["anvim.logcat"] = nil
    lc = require("anvim.logcat")
    local cmd = lc._build_cmd("I")
    assert(cmd[1] == "adb" and cmd[2] == "-s" and cmd[3] == "emulator-5554", "got " .. table.concat(cmd, " "))
    package.loaded["anvim.devices"] = { get_active = function() return nil end }
    package.loaded["anvim.logcat"] = nil
    lc = require("anvim.logcat")
  end)

  run("logcat: open creates buf + win", function()
    lc.running = false; lc.buf = nil; lc.win = nil
    lc.open("I")
    assert(lc.running == true)
    assert(lc.buf ~= nil)
    assert(lc.win ~= nil)
  end)

  run("logcat: open warns if adb missing", function()
    mock.raw("fn.executable", function() return 0 end)
    alert_state.warn_called = false
    lc.running = false; lc.buf = nil; lc.win = nil
    lc.open("I")
    assert(alert_state.warn_called == true)
    mock.raw("fn.executable", function(name)
      if name == "adb" then return 1 end
      return 0
    end)
  end)

  run("logcat: close_win tidak buka dashboard by default", function()
    local dash_called = false
    package.loaded["anvim.dashboard"] = { open = function() dash_called = true end }
    lc.win = 32; lc.buf = 31; lc.running = true; lc.job_id = 1
    lc.close_win()
    assert(lc.win == nil)
    assert(dash_called == false, "default no_dashboard=true → jangan buka dashboard")
  end)

  run("logcat: close_win buka dashboard jika opt-out", function()
    package.loaded["anvim.config"] = {
      get = function()
        return { logcat = { max_lines = 5, filter_default = "I", no_dashboard_on_close = false } }
      end,
    }
    local dash_called = false
    package.loaded["anvim.dashboard"] = { open = function() dash_called = true end }
    lc.win = 32; lc.buf = 31
    lc.close_win()
    assert(dash_called == true)
    package.loaded["anvim.config"] = {
      get = function()
        return { logcat = { max_lines = 5, filter_default = "I", no_dashboard_on_close = true } }
      end,
    }
  end)

  run("logcat: history di-trim ke max_lines", function()
    local stdout_cb
    mock.raw("fn.jobstart", function(_, opts) stdout_cb = opts.on_stdout return 1 end)
    lc.running = false; lc.buf = nil; lc.win = nil; lc.history = {}
    lc.open("I")
    assert(stdout_cb ~= nil)
    local big = {}
    for i = 1, 20 do table.insert(big, "l" .. i) end
    stdout_cb(nil, big)
    assert(#lc.history <= 5, "history harus <=5, got " .. #lc.history)
  end)

  run("logcat: stop clears job", function()
    lc.running = true; lc.job_id = 1
    lc.stop()
    assert(lc.running == false)
    assert(lc.job_id == nil)
  end)
end
