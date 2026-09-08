-- test_init.lua — leader fix + no_default_keymaps

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  run("init: pakai <leader>ad bukan spasi+ad", function()
    local keys = {}
    mock.raw("api.nvim_create_user_command", function() end)
    mock.raw("keymap.set", function(_, lhs) table.insert(keys, lhs) end)
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end }
    package.loaded["anvim.config"] = { setup = function() end }
    vim.g.anvim_loaded = nil
    vim.g.anvim_no_default_keymaps = nil
    vim.g.mapleader = " "
    package.loaded["anvim.init"] = nil
    package.loaded["anvim"] = nil
    -- require via init path
    package.loaded["anvim.config"] = { setup = function() end }
    local init = require("anvim.init")
    init.setup({})
    local has_leader = false
    for _, k in ipairs(keys) do if k == "<leader>ad" or k == "<leader>al" then has_leader = true end end
    assert(has_leader, "harus ada <leader>ad, got: " .. table.concat(keys, ","))
    for _, k in ipairs(keys) do assert(k:sub(1, 1) ~= " ", "tidak boleh spasi+ad: " .. k) end
  end)

  run("init: hormati no_default_keymaps", function()
    local n = 0
    mock.raw("keymap.set", function() n = n + 1 end)
    vim.g.anvim_loaded = nil
    vim.g.anvim_no_default_keymaps = true
    package.loaded["anvim.init"] = nil
    local init = require("anvim.init")
    init.setup({})
    assert(n == 0, "tidak boleh set keymap, got " .. n)
    vim.g.anvim_no_default_keymaps = nil
  end)

  run("init: register AnvimTest + AnvimCustom", function()
    local cmds = {}
    local fns = {}
    mock.raw("api.nvim_create_user_command", function(name, fn) table.insert(cmds, name) fns[name] = fn end)
    mock.raw("keymap.set", function() end)
    vim.g.anvim_loaded = nil
    vim.g.anvim_no_default_keymaps = true
    package.loaded["anvim.init"] = nil
    local init = require("anvim.init")
    init.setup({})
    local has = function(n)
      for _, c in ipairs(cmds) do if c == n then return true end end
      return false
    end
    assert(has("AnvimTest"), "AnvimTest hilang: " .. table.concat(cmds, ","))
    assert(has("AnvimCustom"), "AnvimCustom hilang")
    assert(has("AnvimEmulator"), "AnvimEmulator hilang")
    assert(has("AnvimRerun"), "AnvimRerun hilang")
    assert(has("AnvimScrcpy"), "AnvimScrcpy hilang")
    assert(has("AnvimScrcpyKill"), "AnvimScrcpyKill hilang")
    assert(has("AnvimDoctor"), "AnvimDoctor hilang")
    assert(has("AnvimLogcatSave"), "AnvimLogcatSave hilang")
    assert(has("AnvimHelp"), "AnvimHelp hilang")
    vim.g.anvim_no_default_keymaps = nil
  end)

  run("init: AnvimRun guard unknown", function()
    local cmds = {}
    local fns = {}
    mock.raw("api.nvim_create_user_command", function(name, fn) table.insert(cmds, name) fns[name] = fn end)
    mock.raw("keymap.set", function() end)
    vim.g.anvim_loaded = nil
    vim.g.anvim_no_default_keymaps = true
    local warned, ran = false, false
    package.loaded["anvim.status-alert"] = { info = function() end,
      warn = function() warned = true end, error = function() end, ok = function() end }
    package.loaded["anvim.project"] = { detect = function() return { type = "unknown" } end }
    package.loaded["anvim.tasks"] = { run = function() ran = true end }
    package.loaded["anvim.init"] = nil
    require("anvim.init").setup({})
    fns["AnvimRun"]()
    assert(warned == true, "unknown harus warn")
    assert(ran == false, "run tidak boleh jalan")
    vim.g.anvim_no_default_keymaps = nil
  end)

  run("init: setup tanam dir adb ke PATH", function()
    mock.raw("api.nvim_create_user_command", function() end)
    mock.raw("keymap.set", function() end)
    mock.raw("fn.exepath", function(name)
      if name == "adb" then return "/sdk/platform-tools/adb" end
      return ""
    end)
    mock.raw("fn.executable", function(p)
      if tostring(p):find("platform%-tools/adb") then return 1 end
      return 0
    end)
    mock.raw("fn.expand", function(s) return s end)
    mock.raw("fn.glob", function() return {} end)
    mock.raw("env.PATH", "/usr/bin:/bin")
    vim.g.anvim_loaded = nil
    vim.g.anvim_no_default_keymaps = true
    package.loaded["anvim.init"] = nil
    package.loaded["anvim.system_check"] = nil
    package.loaded["anvim.util"] = nil
    require("anvim.init").setup({})
    assert(vim.env.PATH:find("/sdk/platform-tools", 1, true), "dir adb harus di PATH: " .. vim.env.PATH)
    vim.g.anvim_no_default_keymaps = nil
  end)
end
