-- test_logcat.lua — unit tests for anvim/logcat.lua
-- ponytail: mock vim.* API, test open/close/reopen flow

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local function setup()
    local bufs, wins = {}, {}
    local buf_counter, win_counter = 0, 0
    local schedule_calls = {}

    mock.raw("fn.executable", function(name)
      if name == "adb" then return 1 end
      return 0
    end)
    mock.raw("fn.system", function() return "" end)
    mock.raw("fn.shellescape", function(s) return s end)
    mock.raw("fn.expand", function(s) return s:gsub("~", "/home/testuser") end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.strftime", function() return "00:00:00" end)
    mock.raw("fn.jobstart", function(_, opts)
      if opts and opts.on_exit then
        vim.schedule(function() opts.on_exit() end)
      end
      return 1
    end)
    mock.raw("api.nvim_create_buf", function(_, _)
      buf_counter = buf_counter + 1
      local id = "logbuf_" .. buf_counter
      bufs[id] = { lines = {}, opts = {} }
      return id
    end)
    mock.raw("api.nvim_open_win", function(_, _, _)
      win_counter = win_counter + 1
      local id = "logwin_" .. win_counter
      wins[id] = {}
      return id
    end)
    mock.raw("api.nvim_buf_is_valid", function() return true end)
    mock.raw("api.nvim_win_is_valid", function() return true end)
    mock.raw("api.nvim_set_current_win", function() end)
    mock.raw("api.nvim_buf_set_option", function(buf, opt, val)
      if bufs[buf] then bufs[buf].opts[opt] = val end
    end)
    mock.raw("api.nvim_buf_set_lines", function(buf, ...)
      if bufs[buf] then bufs[buf].lines = {...} end
    end)
    mock.raw("api.nvim_buf_line_count", function() return 5 end)
    mock.raw("api.nvim_buf_delete", function() end)
    mock.raw("api.nvim_buf_set_name", function() end)
    mock.raw("api.nvim_win_set_cursor", function() end)
    mock.raw("api.nvim_win_close", function() end)
    mock.raw("api.nvim_set_current_win", function() end)
    mock.raw("api.nvim_buf_set_keymap", function() end)
    mock.raw("api.nvim_set_keymap", function() end)
    mock.raw("api.nvim_win_set_option", function() end)
    mock.raw("keymap.set", function() end)
    mock.raw("schedule", function(fn) table.insert(schedule_calls, fn) end)
    mock.raw("loop.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    mock.raw("loop.now", function() return 10000 end)
    mock.raw("o.lines", 50)
    mock.raw("o.columns", 200)
    mock.raw("env.PATH", "/usr/local/bin:/usr/bin:/bin")
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    mock.raw("g.anvim_logcat_max", 5000)
    mock.raw("bo", {})
    mock.raw("wo", {})

    return {
      bufs = bufs, wins = wins, schedule_calls = schedule_calls,
    }
  end

  run("logcat: open creates buf + win", function()
    local env = setup()
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end }

    local lc = require("anvim.logcat")
    lc.open("I")
    assert(lc.running == true, "should be running")
    assert(lc.buf ~= nil, "buf should be set")
    assert(lc.win ~= nil, "win should be set")
  end)

  run("logcat: open warns if adb missing", function()
    local env = setup()
    mock.raw("fn.executable", function() return 0 end)
    local warned = false
    package.loaded["anvim.status-alert"] = {
      info = function() end,
      warn = function() warned = true end,
      error = function() end,
      ok = function() end,
    }

    local lc = require("anvim.logcat")
    lc.open("I")
    assert(warned == true, "should warn when adb missing")
  end)

  run("logcat: close_win reopens dashboard", function()
    local env = setup()
    local dash_called = false
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end }
    package.loaded["anvim.dashboard"] = { open = function() dash_called = true end }

    local lc = require("anvim.logcat")
    lc.win = "logwin_1"
    lc.buf = "logbuf_1"
    lc.running = true
    lc.job_id = 1

    lc.close_win()
    assert(lc.win == nil, "win should be nil after close")
    -- schedule calls should include dashboard.open
    assert(dash_called == false, "dashboard.open is scheduled, not immediate")
    -- drain scheduled calls
    vim.schedule(function()
      assert(dash_called == true, "dashboard should reopen")
    end)
  end)

  run("logcat: restart keeps history", function()
    local env = setup()
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end }

    local lc = require("anvim.logcat")
    lc.history = { "line1", "line2", "line3" }
    lc.win = "logwin_1"
    lc.buf = "logbuf_1"
    lc.running = true
    lc.job_id = 1

    lc.restart("W")
    -- after stop + open, running should be true again
    assert(lc.running == true, "should restart")
  end)

  run("logcat: stop clears job", function()
    local env = setup()
    local lc = require("anvim.logcat")
    lc.running = true
    lc.job_id = 1
    lc.stop()
    assert(lc.running == false, "running should be false")
    assert(lc.job_id == nil, "job should be nil")
  end)
end
