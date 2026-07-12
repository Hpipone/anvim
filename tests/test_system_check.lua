-- test_system_check.lua — unit tests for anvim/system_check.lua
-- ponytail: mock vim.* API, test check + format + multi-select

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local function setup()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.exepath", function(name) return "/usr/bin/" .. name end)
    mock.raw("fn.system", function() return "" end)
    mock.raw("fn.expand", function(s) return s:gsub("~", "/home/testuser") end)
    mock.raw("fn.shellescape", function(s) return s end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.input", function() return "1" end)
    mock.raw("fn.glob", function() return {} end)
    mock.raw("fn.strftime", function() return "00:00:00" end)
    mock.raw("fn.filewritable", function() return 0 end)
    mock.raw("loop.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    mock.raw("loop.now", function() return 10000 end)
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
  end

  run("system_check: check_all returns results", function()
    setup()
    local sc = require("anvim.system_check")
    local results = sc.check_all({ "adb", "git" })
    assert(results ~= nil)
    assert(results.adb ~= nil, "expected adb result")
    assert(results.git ~= nil, "expected git result")
    assert(results.adb.found == true, "adb should be found")
    assert(results.git.found == true, "git should be found")
  end)

  run("system_check: get_missing returns only missing", function()
    setup()
    local sc = require("anvim.system_check")
    sc.check_all({ "adb", "git" })
    -- both found
    local missing = sc.get_missing()
    assert(#missing == 0, "expected 0 missing, got " .. #missing)
  end)

  run("system_check: format_line formats found", function()
    setup()
    local sc = require("anvim.system_check")
    local line = sc.format_line("adb", { found = true, path = "/usr/bin/adb" })
    assert(line:match("✓"), "expected checkmark")
  end)

  run("system_check: interactive uses checks", function()
    setup()
    package.loaded["anvim.dashboard"] = { open = function() end }
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end }

    local sc = require("anvim.system_check")
    -- should not crash, calls check_all + prints then returns (all found)
    sc.interactive()
    assert(true, "interactive completed without error")
  end)
end
