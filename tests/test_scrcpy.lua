-- test_scrcpy.lua

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local function setup()
    mock.raw("fn.exepath", function() return "" end)
    mock.raw("fn.executable", function(p)
      if tostring(p):find("scrcpy") then return 1 end
      return 0
    end)
    mock.raw("fn.expand", function(s) return (s:gsub("~", "/home/testuser")) end)
    mock.raw("fn.shellescape", function(s) return "'" .. s .. "'" end)
    mock.raw("fn.glob", function(p)
      if tostring(p):find("scrcpy") then return { "/home/testuser/.anvim/tools/scrcpy/scrcpy" } end
      return {}
    end)
    mock.raw("fn.mkdir", function() end)
    mock.raw("fn.system", function() return "" end)
    mock.raw("fn.jobstart", function() return 9 end)
    mock.raw("fn.jobstop", function() end)
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end, debug = function() end }
    package.loaded["anvim.config"] = {
      get = function()
        return { scrcpy = { replace_emulator = true, max_size = 1920, bit_rate = "8M", audio = false, stay_awake = true, turn_screen_off = true, record_dir = "~/Videos" } }
      end,
    }
    package.loaded["anvim.devices"] = {
      list = function() return { { id = "RF123", model = "Pixel", status = "device" } } end,
    }
  end

  run("scrcpy: find_binary dari tools-dir (no_deploy)", function()
    setup()
    package.loaded["anvim.scrcpy"] = nil
    package.loaded["anvim.util"] = nil
    local s = require("anvim.scrcpy")
    assert(s.find_binary() == "/home/testuser/.anvim/tools/scrcpy/scrcpy")
  end)

  run("scrcpy: build_cmd flag full-custom", function()
    setup()
    package.loaded["anvim.scrcpy"] = nil
    package.loaded["anvim.util"] = nil
    local s = require("anvim.scrcpy")
    local cmd = s.build_cmd("RF123", {})
    local j = table.concat(cmd, " ")
    assert(j:find("%-s RF123"), j)
    assert(j:find("%-%-max%-size 1920"), j)
    assert(j:find("%-%-video%-bit%-rate 8M"), j)
    assert(j:find("%-%-no%-audio"), j)
    assert(j:find("%-%-stay%-awake"), j)
    assert(j:find("%-%-turn%-screen%-off"), j)
  end)

  run("scrcpy: build_cmd record path", function()
    setup()
    package.loaded["anvim.scrcpy"] = nil
    package.loaded["anvim.util"] = nil
    local s = require("anvim.scrcpy")
    local cmd = s.build_cmd("RF123", { record = "/tmp/r.mp4" })
    local j = table.concat(cmd, " ")
    assert(j:find("%-%-record /tmp/r.mp4"), j)
  end)

  run("scrcpy: id_from_label", function()
    setup()
    package.loaded["anvim.scrcpy"] = nil
    package.loaded["anvim.util"] = nil
    local s = require("anvim.scrcpy")
    assert(s._id_from_label("○ mirror  RF123 (Pixel)") == "RF123")
    assert(s._id_from_label(nil) == nil)
  end)

  run("scrcpy: launch + stop tracking", function()
    setup()
    package.loaded["anvim.scrcpy"] = nil
    package.loaded["anvim.util"] = nil
    local s = require("anvim.scrcpy")
    local done
    s.launch("RF123", {}, function(ok) done = ok end)
    assert(s.is_running("RF123") == true)
    s.stop("RF123")
    assert(s.is_running("RF123") == false)
  end)

  run("scrcpy: launch tolak tanpa binary", function()
    setup()
    mock.raw("fn.exepath", function() return "" end)
    mock.raw("fn.executable", function() return 0 end)
    mock.raw("fn.glob", function() return {} end)
    package.loaded["anvim.scrcpy"] = nil
    package.loaded["anvim.util"] = nil
    local s = require("anvim.scrcpy")
    local done
    s.launch("RF123", {}, function(ok) done = ok end)
    assert(done == false)
  end)

  run("scrcpy: TOOLS spec no_deploy + tools glob", function()
    setup()
    mock.raw("uv.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    local spec = sc.get_tools_spec().scrcpy
    assert(spec ~= nil and spec.optional == true)
    assert(spec.download.linux.no_deploy == true, "scrcpy wajib no_deploy")
    assert(spec.download.linux.dir ~= nil)
  end)
end
