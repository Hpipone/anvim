-- test_flutter.lua

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  run("flutter: parse machine object + array", function()
    mock.raw("fn.executable", function() return 1 end)
    package.loaded["anvim.flutter"] = nil
    local f = require("anvim.flutter")
    local out = table.concat({
      '{"id":"emulator-5554","name":"sdk gphone","targetPlatform":"android-arm64"}',
      '[{"id":"chrome","name":"Chrome","targetPlatform":"web-javascript"}]',
      'not json line',
    }, "\n")
    local devs = f._parse_machine(out)
    assert(#devs == 2, "got " .. #devs)
    assert(devs[1].id == "emulator-5554" and devs[1].platform == "android-arm64")
    assert(devs[2].id == "chrome")
  end)

  run("flutter: empty saat binary hilang", function()
    mock.raw("fn.executable", function() return 0 end)
    package.loaded["anvim.flutter"] = nil
    local f = require("anvim.flutter")
    assert(#f.list() == 0)
  end)

  run("flutter: empty saat output rusak", function()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.system", function() return "garbage ((( " end)
    package.loaded["anvim.flutter"] = nil
    local f = require("anvim.flutter")
    assert(#f.list() == 0)
  end)

  run("flutter: list di-cache (spawn sekali)", function()
    local n = 0
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.system", function() n = n + 1 return "" end)
    package.loaded["anvim.flutter"] = nil
    local f = require("anvim.flutter")
    f.list()
    f.list()
    assert(n == 1, "harus 1 spawn, got " .. n)
  end)
end
