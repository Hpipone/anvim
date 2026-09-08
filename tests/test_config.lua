-- test_config.lua

return function(ctx)
  local run = ctx.run
  run("config: defaults lengkap v1.6.2", function()
    package.loaded["anvim.config"] = nil
    local c = require("anvim.config")
    c.setup({})
    local g = c.get()
    assert(g.version == "1.6.2", "got " .. tostring(g.version))
    assert(g.dashboard.width == 0.8)
    assert(g.dashboard.border == "rounded")
    assert(g.logcat.max_lines == 5000)
    assert(g.tasks.timeout_ms == 300000)
    assert(type(g.tasks.custom) == "table")
    assert(g.install ~= nil)
  end)
  run("config: setup merge opts", function()
    package.loaded["anvim.config"] = nil
    local c = require("anvim.config")
    c.setup({ dashboard = { width = 0.5 } })
    assert(c.get().dashboard.width == 0.5)
    assert(c.get().dashboard.border == "rounded")
  end)
end
