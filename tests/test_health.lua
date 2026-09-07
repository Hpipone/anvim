-- test_health.lua — shim delegasi

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  run("health: shim check_all ada summary", function()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.exepath", function(n) return "/usr/bin/" .. n end)
    mock.raw("fn.system", function() return "" end)
    mock.raw("fn.expand", function(s) return (s:gsub("~", "/home/t")) end)
    mock.raw("fn.shellescape", function(s) return s end)
    mock.raw("fn.glob", function() return {} end)
    mock.raw("fn.strftime", function() return "00:00:00" end)
    mock.raw("uv.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end, debug = function() end }
    package.loaded["anvim.health"] = nil
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local h = require("anvim.health")
    local r = h.check_all()
    assert(r.tools ~= nil and r.summary ~= nil)
    assert(h.format_line("adb", { found = true, path = "/usr/bin/adb", label = "ADB" }):find("✓"))
  end)
end
