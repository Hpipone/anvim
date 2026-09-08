-- test_statusline.lua

return function(ctx)
  local run = ctx.run

  run("statusline: text ringkas tanpa crash", function()
    package.loaded["anvim.project"] = {
      detect = function() return { name = "app", type = "flutter" } end,
    }
    package.loaded["anvim.devices"] = { get_active = function() return "emulator-5554" end }
    package.loaded["anvim.tasks"] = { state = { running = true, current = "run" } }
    package.loaded["anvim.statusline"] = nil
    local s = require("anvim.statusline")
    local t = s.text()
    assert(t:find("app") and t:find("emulator%-5554") and t:find("run"), "got " .. t)
    assert(s.render():find("anvim:"))
    assert(type(s.lualine()) == "string")
  end)

  run("statusline: kosong saat unknown", function()
    package.loaded["anvim.project"] = {
      detect = function() return { name = "x", type = "unknown" } end,
    }
    package.loaded["anvim.devices"] = { get_active = function() return nil end }
    package.loaded["anvim.tasks"] = { state = { running = false } }
    package.loaded["anvim.statusline"] = nil
    local s = require("anvim.statusline")
    assert(s.text() == "", "got " .. s.text())
    assert(s.render() == "")
  end)

  run("statusline: detect di-cache + invalidate", function()
    local n = 0
    package.loaded["anvim.project"] = {
      detect = function() n = n + 1 return { name = "app", type = "flutter" } end,
    }
    package.loaded["anvim.devices"] = { get_active = function() return nil end }
    package.loaded["anvim.tasks"] = { state = { running = false } }
    package.loaded["anvim.statusline"] = nil
    local s = require("anvim.statusline")
    s.text()
    s.text()
    assert(n == 1, "detect harus sekali, got " .. n)
    s.invalidate()
    s.text()
    assert(n == 2, "invalidate harus hitung ulang, got " .. n)
  end)
end
