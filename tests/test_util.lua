-- test_util.lua

return function(ctx)
  local run = ctx.run
  local mock = ctx.mock

  mock.raw("uv.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
  mock.raw("fn.expand", function(s) return (s:gsub("~", "/home/testuser")) end)
  mock.raw("fn.shellescape", function(s) return "'" .. s .. "'" end)
  mock.raw("o.columns", 200)
  mock.raw("o.lines", 50)

  package.loaded["anvim.util"] = nil
  local util = require("anvim.util")

  run("util: detect_os linux/macos/windows", function()
    assert(util.detect_os("Linux") == "linux")
    assert(util.detect_os("Darwin") == "macos")
    assert(util.detect_os("Windows_NT") == "windows")
  end)

  run("util: is_safe_bin_name menolak injection", function()
    assert(util.is_safe_bin_name("adb") == true)
    assert(util.is_safe_bin_name("flutter") == true)
    assert(util.is_safe_bin_name("a;rm -rf /") == false)
    assert(util.is_safe_bin_name("a/b") == false)
    assert(util.is_safe_bin_name("") == false)
    assert(util.is_safe_bin_name(nil) == false)
  end)

  run("util: float_geom clamp layar kecil", function()
    mock.raw("o.columns", 80)
    mock.raw("o.lines", 24)
    local w, h, col, row = util.float_geom(0.8, 0.8, 50, 14)
    assert(w <= 78, "w=" .. w)
    assert(h <= 22, "h=" .. h)
    assert(col >= 0 and row >= 0)
    mock.raw("o.columns", 200)
    mock.raw("o.lines", 50)
  end)

  run("util: tbl_count untuk dict", function()
    assert(util.tbl_count({ a = 1, b = 2 }) == 2)
    assert(util.tbl_count({}) == 0)
  end)

  run("util: sorted_tool_names stabil", function()
    local names = util.sorted_tool_names({ git = {}, adb = {} })
    assert(names[1] == "adb" and names[2] == "git", table.concat(names, ","))
  end)

  run("util: shell_rcs multi-shell", function()
    local rcs = util.shell_rcs()
    assert(#rcs >= 1)
  end)
end
