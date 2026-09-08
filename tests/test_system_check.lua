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
    mock.raw("api.nvim_buf_set_name", function() end)
    mock.raw("api.nvim_win_close", function() end)
    mock.raw("api.nvim_buf_add_highlight", function() end)
    mock.raw("api.nvim_set_hl", function() end)
    mock.raw("keymap.set", function() end)
    mock.raw("schedule", function(fn) fn() end)
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

  run("system_check: parse version tiap tool", function()
    setup()
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    assert(sc._parse_version("java", 'openjdk 17.0.9 2023-10-17')[1] == 17)
    assert(sc._parse_version("gradle", "Gradle 9.7.1")[2] == 7)
    assert(sc._parse_version("adb", "Android Debug Bridge version 1.0.41")[3] == 41)
    assert(sc._parse_version("flutter", "Flutter 3.47.0 • channel stable")[1] == 3)
    assert(sc._parse_version("git", "git version 2.43.0")[1] == 2)
    assert(sc._parse_version("java", "") == nil)
  end)

  run("system_check: meets_min menolak versi lama", function()
    setup()
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    assert(sc._meets_min("java", { 17, 0, 9 }) == true)
    assert(sc._meets_min("java", { 11, 0, 2 }) == false)
    assert(sc._meets_min("gradle", { 9, 7, 1 }) == true)
    assert(sc._meets_min("gradle", { 7, 6 }) == false)
  end)

  run("system_check: outdated + format old", function()
    setup()
    mock.raw("fn.system", function(cmd)
      cmd = tostring(cmd)
      if cmd:find("java") then return "openjdk 11.0.2" end
      return ""
    end)
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    sc.check_all({ "java" })
    local out = sc.get_outdated()
    assert(#out == 1 and out[1] == "java", "got " .. table.concat(out, ","))
    local line = sc.format_line("java", sc.results.java)
    assert(line:find("⚠") and line:find("min 17"), "got " .. line)
  end)

  run("system_check: emulator optional tidak masuk missing", function()
    setup()
    mock.raw("fn.executable", function() return 0 end)
    mock.raw("fn.exepath", function() return "" end)
    mock.raw("fn.glob", function() return {} end)
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    sc.check_all({ "adb", "emulator" })
    for _, m in ipairs(sc.get_missing()) do
      assert(m ~= "emulator", "emulator optional jangan masuk missing")
    end
  end)

  run("system_check: interactive missing buka UI selectable", function()
    setup()
    mock.raw("fn.executable", function() return 0 end)
    mock.raw("fn.exepath", function() return "" end)
    mock.raw("fn.glob", function() return {} end)
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    sc.interactive()
    assert(sc._ui.buf ~= nil, "UI buf harus dibuka saat ada missing")
    assert(#sc._ui.items > 0)
    sc._ui_nav(1)
    sc._ui_nav(-1)
    sc._ui_close()
    assert(sc._ui.buf == nil, "UI harus bersih setelah close")
  end)

  run("system_check: env issues + doctor", function()
    setup()
    mock.raw("env.ANDROID_HOME", "")
    mock.raw("env.ANDROID_SDK_ROOT", "")
    mock.raw("fn.isdirectory", function() return 0 end)
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    local issues = sc.get_env_issues()
    assert(#issues >= 1, "tanpa ANDROID_HOME harus ada issue")
    sc.doctor()
    assert(true)
  end)

  run("system_check: UI tetap buka untuk optional installable", function()
    setup()
    -- semua wajib ada, scrcpy (optional) hilang tapi bisa di-download
    mock.raw("fn.executable", function(p)
      if tostring(p):find("scrcpy") then return 0 end
      return 1
    end)
    mock.raw("fn.exepath", function(name)
      if name == "scrcpy" then return "" end
      return "/usr/bin/" .. name
    end)
    mock.raw("fn.glob", function() return {} end)
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    sc.interactive()
    assert(sc._ui.buf ~= nil, "UI harus buka untuk tawarkan scrcpy")
    local found = false
    for _, it in ipairs(sc._ui.items) do
      if it.name == "scrcpy" and it.kind == "installable" then found = true end
    end
    assert(found == true, "scrcpy harus installable")
    sc._ui_close()
  end)

  run("system_check: tanpa highlight baris (cursor only)", function()
    setup()
    local n_hl = 0
    mock.raw("api.nvim_buf_add_highlight", function() n_hl = n_hl + 1 end)
    mock.raw("fn.executable", function() return 0 end)
    mock.raw("fn.exepath", function() return "" end)
    mock.raw("fn.glob", function() return {} end)
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    sc.interactive()
    sc._ui_nav(1)
    assert(n_hl == 0, "nol highlight, got " .. n_hl)
    sc._ui_close()
  end)

  run("system_check: required_tools scoped per tipe", function()
    setup()
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    local node = sc.required_tools("node")
    local has = function(t, n)
      for _, x in ipairs(t) do if x == n then return true end end
      return false
    end
    assert(has(node, "node") and has(node, "git"), table.concat(node, ","))
    assert(not has(node, "flutter"), "node tak boleh ditagih flutter")
    local fl = sc.required_tools("flutter")
    assert(has(fl, "adb") and has(fl, "flutter") and not has(fl, "gradle"))
    local an = sc.required_tools("android")
    assert(has(an, "java") and has(an, "gradle") and not has(an, "flutter"))
  end)

  run("system_check: adb_bin absolut + cache", function()
    setup()
    mock.raw("fn.exepath", function(name)
      if name == "adb" then return "/sdk/platform-tools/adb" end
      return ""
    end)
    mock.raw("fn.executable", function(p)
      if tostring(p) == "/sdk/platform-tools/adb" then return 1 end
      return 0
    end)
    mock.raw("fn.glob", function() return {} end)
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    local sc = require("anvim.system_check")
    assert(sc.adb_bin() == "/sdk/platform-tools/adb", "got " .. tostring(sc.adb_bin()))
    mock.raw("fn.exepath", function() return "" end)
    assert(sc.adb_bin() == "/sdk/platform-tools/adb", "cache harus dipakai")
    sc.reset_cache()
    assert(sc.adb_bin() == nil, "reset harus kosongkan")
  end)
end
