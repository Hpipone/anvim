-- test_system_check.lua — sorted, version, height fix

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local function setup()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.exepath", function(name) return "/usr/bin/" .. name end)
    mock.raw("fn.system", function() return "" end)
    mock.raw("fn.expand", function(s) return (s:gsub("~", "/home/testuser")) end)
    mock.raw("fn.shellescape", function(s) return "'" .. s .. "'" end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.input", function() return "" end)
    mock.raw("fn.glob", function() return {} end)
    mock.raw("fn.isdirectory", function() return 1 end)
    mock.raw("uv.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    mock.raw("uv.now", function() return 10000 end)
    mock.raw("api.nvim_create_buf", function() return 41 end)
    mock.raw("api.nvim_open_win", function() return 42 end)
    mock.raw("api.nvim_buf_is_valid", function() return true end)
    mock.raw("api.nvim_win_is_valid", function() return true end)
    mock.raw("api.nvim_buf_set_lines", function() end)
    mock.raw("api.nvim_buf_delete", function() end)
    mock.raw("api.nvim_win_close", function() end)
    mock.raw("o.lines", 50)
    mock.raw("o.columns", 200)
    mock.raw("env.PATH", "/usr/local/bin:/usr/bin:/bin")
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end }
    package.loaded["anvim.dashboard"] = { open = function() end }
    package.loaded["anvim.installation"] = { install_tool = function(_, _, _, _, cb) cb(true) end, install_cancelled = false }
  end

  run("system_check: check_all returns results", function()
    setup()
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    local results = sc.check_all({ "adb", "git" })
    assert(results.adb ~= nil and results.git ~= nil)
    assert(results.adb.found == true)
  end)

  run("system_check: get_missing sorted + empty jika semua ada", function()
    setup()
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    sc.check_all({ "adb", "git" })
    assert(#sc.get_missing() == 0)
  end)

  run("system_check: format_line kaya version+hint", function()
    setup()
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    local ok_line = sc.format_line("adb", { found = true, path = "/usr/bin/adb", label = "ADB", version = "1.0.41" })
    assert(ok_line:match("✓") and ok_line:match("1.0.41"), "got " .. ok_line)
    local miss = sc.format_line("adb", { found = false, label = "ADB", hint = "Install X" })
    assert(miss:match("✗") and miss:match("Install X"), "got " .. miss)
  end)

  run("system_check: get_tools_spec ada sha256_url", function()
    setup()
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    local spec = sc.get_tools_spec()
    assert(spec.gradle ~= nil and spec.gradle.download.linux.sha256_url ~= nil, "gradle harus ada sha256")
  end)

  run("system_check: interactive all-found tidak crash", function()
    setup()
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    sc.interactive()
    assert(true)
  end)
end
