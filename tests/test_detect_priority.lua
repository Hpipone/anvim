-- test_detect_priority.lua — canonical ~/.local/bin menang atas tools-dir

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local HOME = "/home/testuser"
  local BIN = HOME .. "/.local/bin"
  local TOOLS = HOME .. "/.anvim/tools/adb/platform-tools"

  local function setup(path_state)
    -- path_state: { bin_dir = true/false, tools_dir = true/false, path_exe = nil|path }
    mock.raw("uv.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    mock.raw("fn.expand", function(s) return (s:gsub("~", HOME)) end)
    mock.raw("fn.exepath", function(name)
      if name == "adb" and path_state.path_exe then return path_state.path_exe end
      return ""
    end)
    mock.raw("fn.executable", function(p)
      p = tostring(p)
      if p == BIN .. "/adb" then return path_state.bin_dir and 1 or 0 end
      if p == TOOLS .. "/adb" then return path_state.tools_dir and 1 or 0 end
      if p == "find" then return 0 end
      return 0
    end)
    mock.raw("fn.glob", function() return {} end)
    mock.raw("fn.isdirectory", function() return 0 end)
    mock.raw("fn.system", function() return "" end)
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    mock.raw("env.PATH", "/usr/bin:/bin")
    mock.raw("env.ANDROID_HOME", "")
    mock.raw("env.ANDROID_SDK_ROOT", "")
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end, debug = function() end }
    package.loaded["anvim.config"] = {
      get = function()
        return { install = {}, detect = { extra_dirs = {}, max_depth = 3, cache_ttl = 300 }, health_check = { tools = { "adb" } } }
      end,
    }
    package.loaded["anvim.util"] = nil
    package.loaded["anvim.system_check"] = nil
  end

  run("detect: bin_dir menang atas tools-dir di PATH", function()
    -- simulasi PATH kotor sesi lama: tools-dir duluan
    setup({ bin_dir = true, tools_dir = true, path_exe = TOOLS .. "/adb" })
    local sc = require("anvim.system_check")
    local r = sc.check_tool("adb")
    assert(r.found == true)
    assert(r.path == BIN .. "/adb", "harus kanonis local/bin, got " .. tostring(r.path))
  end)

  run("detect: fallback PATH bila bin_dir kosong", function()
    setup({ bin_dir = false, tools_dir = true, path_exe = TOOLS .. "/adb" })
    local sc = require("anvim.system_check")
    local r = sc.check_tool("adb")
    assert(r.path == TOOLS .. "/adb", "got " .. tostring(r.path))
  end)

  run("detect: extra_dirs menemukan binary di Downloads", function()
    setup({ bin_dir = false, tools_dir = false, path_exe = nil })
    mock.raw("fn.isdirectory", function(p)
      if tostring(p) == HOME .. "/Downloads" then return 1 end
      return 0
    end)
    mock.raw("fn.system", function(cmd)
      if tostring(cmd):find("find") then return HOME .. "/Downloads/tool/adb\n" end
      return ""
    end)
    mock.raw("fn.executable", function(p)
      if tostring(p) == HOME .. "/Downloads/tool/adb" then return 1 end
      if tostring(p) == "find" then return 1 end
      return 0
    end)
    package.loaded["anvim.util"] = nil
    package.loaded["anvim.system_check"] = nil
    local sc = require("anvim.system_check")
    local r = sc.check_tool("adb")
    assert(r.found == true and r.path == HOME .. "/Downloads/tool/adb", "got " .. tostring(r.path))
  end)

  run("repair: buang tools-dir dari PATH + pasang bin_dir", function()
    setup({ bin_dir = true, tools_dir = true, path_exe = nil })
    mock.raw("env.PATH", TOOLS .. ":/usr/bin:/bin")
    mock.raw("fn.mkdir", function() end)
    package.loaded["anvim.util"] = nil
    package.loaded["anvim.system_check"] = nil
    local sc = require("anvim.system_check")
    local fixed = sc.repair()
    assert(#fixed >= 1, "harus ada perbaikan")
    assert(not vim.env.PATH:find(TOOLS, 1, true), "tools-dir harus hilang: " .. vim.env.PATH)
    assert(vim.env.PATH:sub(1, #BIN) == BIN, "bin_dir harus di depan: " .. vim.env.PATH)
  end)
end
