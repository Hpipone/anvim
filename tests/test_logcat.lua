-- test_logcat.lua — unit tests for anvim/logcat.lua
-- ponytail: mock vim.* API, test open/close/reopen flow

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
    mock.raw("fn.shellescape", function(s) return s end)
    mock.raw("fn.expand", function(s) return s:gsub("~", "/home/testuser") end)
    mock.raw("fn.jobstart", function() return 1 end)  -- simulate running job
    mock.raw("fn.strftime", function() return "00:00:00" end)
    mock.raw("api.nvim_create_buf", function() return "logbuf_1" end)
    mock.raw("api.nvim_open_win", function() return "logwin_1" end)
    mock.raw("api.nvim_buf_is_valid", function() return true end)
    mock.raw("api.nvim_win_is_valid", function() return true end)
    mock.raw("api.nvim_set_current_win", function() end)
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
    mock.raw("api.nvim_win_set_option", function() end)
    mock.raw("api.nvim_create_user_command", function() end)
    mock.raw("keymap.set", function() end)
    mock.raw("schedule", function(fn) fn() end)
    mock.raw("loop.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    mock.raw("loop.now", function() return 10000 end)
    mock.raw("o.lines", 50)
    mock.raw("o.columns", 200)
    mock.raw("env.PATH", "/usr/local/bin:/usr/bin:/bin")
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    mock.raw("g.anvim_logcat_max", 5000)

    alert_state.warn_called = false

    package.loaded["anvim.status-alert"] = {
      info = function() end,
      warn = function() alert_state.warn_called = true end,
      error = function() end,
      ok = function() end,
    }
    package.loaded["anvim.dashboard"] = { open = function() end }
  end

  init_mocks()
  local lc = require("anvim.logcat")

  run("logcat: open creates buf + win", function()
    lc.open("I")
    assert(lc.running == true, "should be running, got " .. tostring(lc.running))
    assert(lc.buf ~= nil, "buf should be set")
    assert(lc.win ~= nil, "win should be set")
  end)

  run("logcat: open warns if adb missing", function()
    mock.raw("fn.executable", function() return 0 end)
    alert_state.warn_called = false
    -- reset state
    lc.running = false
    lc.buf = nil
    lc.win = nil
    lc.open("I")
    assert(alert_state.warn_called == true, "should warn when adb missing")
  end)

  run("logcat: close_win reopens dashboard", function()
    local dash_called = false
    package.loaded["anvim.dashboard"] = { open = function() dash_called = true end }

    lc.win = "logwin_1"
    lc.buf = "logbuf_1"
    lc.running = true
    lc.job_id = 1

    lc.close_win()
    assert(lc.win == nil, "win should be nil after close")
    assert(dash_called == true, "dashboard should reopen")
  end)

  run("logcat: restart keeps history", function()
    mock.raw("fn.executable", function(name)
      if name == "adb" then return 1 end
      return 0
    end)
    lc.history = { "line1", "line2", "line3" }
    lc.win = "logwin_1"
    lc.buf = "logbuf_1"
    lc.running = true
    lc.job_id = 1

    lc.restart("W")
    assert(lc.running == true, "should restart")
  end)

  run("logcat: stop clears job", function()
    lc.running = true
    lc.job_id = 1
    lc.stop()
    assert(lc.running == false, "running should be false")
    assert(lc.job_id == nil, "job should be nil")
  end)
end
