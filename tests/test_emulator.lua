-- test_emulator.lua

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local function setup()
    mock.raw("fn.exepath", function(name)
      if name == "emulator" then return "" end
      return "/usr/bin/" .. name
    end)
    mock.raw("fn.executable", function(p)
      if tostring(p):find("emulator") then return 1 end
      if p == "adb" then return 1 end
      return 0
    end)
    mock.raw("fn.expand", function(s) return (s:gsub("~", "/home/testuser")) end)
    mock.raw("fn.shellescape", function(s) return "'" .. s .. "'" end)
    mock.raw("fn.system", function() return "" end)
    mock.raw("fn.jobstart", function() return 7 end)
    mock.raw("uv.new_timer", function()
      return { start = function(_, _, _, cb) end, stop = function() end, close = function() end }
    end)
    mock.raw("uv.now", function() return 10000 end)
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    mock.raw("env.ANDROID_HOME", "/home/testuser/Android/Sdk")
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end, debug = function() end }
    package.loaded["anvim.config"] = { get = function() return { emulator = { boot_timeout_ms = 5000 } } end }
    package.loaded["anvim.devices"] = {
      list = function() return {} end,
      set_active = function() return true end,
      get_active = function() return nil end,
    }
  end

  run("emulator: parse list-avds filter INFO", function()
    setup()
    package.loaded["anvim.emulator"] = nil
    package.loaded["anvim.util"] = nil
    local emu = require("anvim.emulator")
    local names = emu._parse_avds("Pixel_6_API_34\nINFO emu info\n\nNexus_5\n")
    assert(#names == 2 and names[1] == "Pixel_6_API_34", "got " .. table.concat(names, ","))
  end)

  run("emulator: find_binary prioritaskan local/bin", function()
    setup()
    package.loaded["anvim.emulator"] = nil
    package.loaded["anvim.util"] = nil
    local emu = require("anvim.emulator")
    assert(emu.find_binary() == "/home/testuser/.local/bin/emulator",
      "got " .. tostring(emu.find_binary()))
  end)

  run("emulator: find_binary fallback ANDROID_HOME", function()
    setup()
    mock.raw("fn.executable", function(p)
      if tostring(p):find("Android/Sdk") then return 1 end
      return 0
    end)
    package.loaded["anvim.emulator"] = nil
    package.loaded["anvim.util"] = nil
    local emu = require("anvim.emulator")
    assert(emu.find_binary() == "/home/testuser/Android/Sdk/emulator/emulator")
  end)

  run("emulator: find_binary nil jika tidak ada", function()
    setup()
    mock.raw("fn.exepath", function() return "" end)
    mock.raw("fn.executable", function() return 0 end)
    mock.raw("env.ANDROID_HOME", "")
    mock.raw("env.ANDROID_SDK_ROOT", "")
    package.loaded["anvim.emulator"] = nil
    package.loaded["anvim.util"] = nil
    local emu = require("anvim.emulator")
    assert(emu.find_binary() == nil)
  end)

  run("emulator: build_launch_cmd cold/wipe/quick", function()
    setup()
    package.loaded["anvim.emulator"] = nil
    package.loaded["anvim.util"] = nil
    local emu = require("anvim.emulator")
    local cold = emu.build_launch_cmd("Pixel", { cold_boot = true })
    assert(cold[2] == "-avd" and cold[4] == "-no-snapshot-load", table.concat(cold, " "))
    local wipe = emu.build_launch_cmd("Pixel", { wipe_data = true })
    assert(wipe[4] == "-wipe-data", table.concat(wipe, " "))
    local quick = emu.build_launch_cmd("Pixel", { cold_boot = false })
    assert(#quick == 3, table.concat(quick, " "))
  end)

  run("emulator: _boot_done hanya '1'", function()
    setup()
    package.loaded["anvim.emulator"] = nil
    package.loaded["anvim.util"] = nil
    local emu = require("anvim.emulator")
    assert(emu._boot_done("1\n") == true)
    assert(emu._boot_done("0\n") == false)
    assert(emu._boot_done("") == false)
  end)

  run("emulator: running_map via emu avd name", function()
    setup()
    mock.raw("fn.system", function(cmd)
      if tostring(cmd):find("emu avd name") then return "Pixel_6_API_34\nOK\n" end
      return ""
    end)
    package.loaded["anvim.emulator"] = nil
    package.loaded["anvim.util"] = nil
    local emu = require("anvim.emulator")
    local map = emu.running_map({ { id = "emulator-5554", status = "device" } })
    assert(map["Pixel_6_API_34"] == "emulator-5554")
  end)

  run("emulator: list_avds di-cache (spawn sekali)", function()
    setup()
    local n = 0
    mock.raw("fn.system", function() n = n + 1 return "Pixel_6\n" end)
    package.loaded["anvim.emulator"] = nil
    package.loaded["anvim.util"] = nil
    local emu = require("anvim.emulator")
    emu.list_avds()
    emu.list_avds()
    assert(n == 1, "harus 1 spawn, got " .. n)
  end)

  run("emulator: kill tanpa id gagal", function()
    setup()
    package.loaded["anvim.emulator"] = nil
    package.loaded["anvim.util"] = nil
    local emu = require("anvim.emulator")
    local done
    emu.kill("", function(ok) done = ok end)
    assert(done == false)
  end)

  run("emulator: launch tanpa binary gagal", function()
    setup()
    mock.raw("fn.exepath", function() return "" end)
    mock.raw("fn.executable", function() return 0 end)
    mock.raw("env.ANDROID_HOME", "")
    mock.raw("env.ANDROID_SDK_ROOT", "")
    package.loaded["anvim.emulator"] = nil
    package.loaded["anvim.util"] = nil
    local emu = require("anvim.emulator")
    local done
    emu.launch("Pixel", {}, function(ok) done = ok end)
    assert(done == false)
  end)
end
