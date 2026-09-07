-- test_dashboard.lua — dashboard config-driven, skip header nav

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local alert_state = { warn_called = false, error_called = false }

  local function init_mocks()
    mock.raw("uv.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    mock.raw("uv.now", function() return 10000 end)
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.exepath", function(name) return "/usr/bin/" .. name end)
    mock.raw("fn.system", function() return "" end)
    mock.raw("fn.expand", function(s) return (s:gsub("~", "/home/testuser")) end)
    mock.raw("fn.shellescape", function(s) return "'" .. s .. "'" end)
    mock.raw("fn.strdisplaywidth", function(s) return #s end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.input", function() return "" end)
    mock.raw("fn.glob", function() return {} end)
    mock.raw("fn.bufwinid", function() return 1000 end)
    mock.raw("fn.mkdir", function() end)
    mock.raw("fn.jobstart", function() return 1 end)
    mock.raw("fn.getcwd", function() return "/home/testuser/proj" end)
    mock.raw("fn.isdirectory", function() return 1 end)
    mock.raw("fn.filereadable", function() return 0 end)
    mock.raw("api.nvim_create_buf", function() return 11 end)
    mock.raw("api.nvim_open_win", function() return 22 end)
    mock.raw("api.nvim_buf_is_valid", function() return true end)
    mock.raw("api.nvim_win_is_valid", function() return true end)
    mock.raw("api.nvim_buf_set_lines", function() end)
    mock.raw("api.nvim_buf_line_count", function() return 5 end)
    mock.raw("api.nvim_buf_delete", function() end)
    mock.raw("api.nvim_buf_set_name", function() end)
    mock.raw("api.nvim_win_set_cursor", function() end)
    mock.raw("api.nvim_win_close", function() end)
    mock.raw("api.nvim_set_current_win", function() end)
    mock.raw("api.nvim_create_user_command", function() end)
    mock.raw("schedule", function(fn) fn() end)
    mock.raw("o.lines", 50)
    mock.raw("o.columns", 200)
    mock.raw("env.PATH", "/usr/local/bin:/usr/bin:/bin")
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    mock.raw("keymap.set", function() end)

    alert_state.warn_called = false
    alert_state.error_called = false

    package.loaded["anvim.status-alert"] = {
      info = function() end,
      warn = function() alert_state.warn_called = true end,
      error = function() alert_state.error_called = true end,
      ok = function() end,
    }
    package.loaded["anvim.system_check"] = {
      check_all = function() return {
        adb = { found = true, path = "/usr/bin/adb", label = "ADB" },
        git = { found = true, path = "/usr/bin/git", label = "Git" },
      } end,
      format_line = function(_, r) return r.found and "✓ ok" or "✗ missing" end,
    }
    package.loaded["anvim.project"] = {
      detect = function() return { name = "test-project", type = "android", branch = "main" } end,
    }
    package.loaded["anvim.devices"] = {
      list = function() return { { id = "emulator-5554", model = "Pixel_6", status = "device" } } end,
      get_active = function() return nil end,
      set_active = function() return true end,
    }
    package.loaded["anvim.tasks"] = { run = function() end, stop = function() end }
    package.loaded["anvim.config"] = {
      get = function() return {
        dashboard = { width = 0.8, height = 0.8, border = "rounded", winblend = 10, min_width = 50, min_height = 14 },
        health_check = { tools = { "adb", "git" }, auto = true },
        tasks = { custom = {} },
      } end,
    }
    package.loaded["anvim.keymaps.dashboard"] = { set = function() end }
    package.loaded["anvim.logcat"] = { open = function() end }
  end

  init_mocks()
  package.loaded["anvim.dashboard"] = nil
  package.loaded["anvim.util"] = nil
  local dash = require("anvim.dashboard")

  run("dashboard: open creates buf + win", function()
    dash.close()
    dash.open()
    assert(dash.state.open == true)
    assert(dash.state.buf ~= nil)
    assert(dash.state.win ~= nil)
  end)

  run("dashboard: open clamps small screen", function()
    mock.raw("o.lines", 24)
    mock.raw("o.columns", 80)
    dash.close()
    dash.open()
    assert(dash.state.open == true, "harus tetap open di layar kecil tanpa error")
    mock.raw("o.lines", 50)
    mock.raw("o.columns", 200)
  end)

  run("dashboard: nav skips header", function()
    dash.state.open = true
    dash.state.buf = 11
    dash.state.win = 22
    dash.state.items = {
      { type = "header", text = "Tasks" },
      { type = "task", label = "a", task = "run", icon = "▶" },
      { type = "header", text = "System" },
      { type = "task", label = "b", task = "check", icon = "⚡" },
    }
    dash.state.selected = 2
    dash.state.proj = { name = "test", type = "android" }
    dash.nav(1)
    assert(dash.state.selected == 4, "harus skip header ke 4, got " .. dash.state.selected)
    dash.nav(1)
    assert(dash.state.selected == 2, "wrap ke 2, got " .. dash.state.selected)
  end)

  run("dashboard: close cleans state", function()
    dash.state.open = true
    dash.state.buf = 11
    dash.state.win = 22
    dash.close()
    assert(dash.state.open == false)
    assert(dash.state.buf == nil)
    assert(dash.state.items ~= nil and #dash.state.items == 0)
  end)

  run("dashboard: do_logcat warns if adb missing", function()
    mock.raw("fn.executable", function(name)
      if name == "adb" then return 0 end
      return 1
    end)
    alert_state.warn_called = false
    dash.state.open = true
    dash.state.buf = 11
    dash.do_logcat()
    assert(alert_state.warn_called == true)
    mock.raw("fn.executable", function() return 1 end)
  end)

  run("dashboard: select task run calls tasks.run", function()
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    local tasks_called = false
    package.loaded["anvim.tasks"] = { run = function() tasks_called = true end, stop = function() end }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.open()
    dash.state.selected = 1
    -- cari index selectable pertama
    for i, it in ipairs(dash.state.items) do
      if it.type == "task" and it.task == "run" then dash.state.selected = i break end
    end
    dash.state.proj = { name = "test", type = "android" }
    dash.select()
    assert(tasks_called == true)
  end)

  run("dashboard: select device validates + set_active", function()
    local active_id
    package.loaded["anvim.devices"] = {
      list = function() return { { id = "emulator-5554", model = "Pixel", status = "device" } } end,
      get_active = function() return nil end,
      set_active = function(id) active_id = id return true end,
    }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    dash.state.selected = 1
    dash.state.items = {
      { type = "device", label = "Pixel (emulator-5554)", device = { id = "emulator-5554", status = "device" } },
    }
    dash.state.proj = { name = "test", type = "android" }
    dash.select()
    assert(active_id == "emulator-5554", "got " .. tostring(active_id))
  end)

  run("dashboard: select invalid device warns", function()
    package.loaded["anvim.devices"] = {
      list = function() return {} end,
      get_active = function() return nil end,
      set_active = function() error("must not call") end,
    }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    dash.state.items = {
      { type = "device", label = "x", device = { id = "gone-123", status = "device" } },
    }
    dash.state.selected = 1
    dash.state.proj = { name = "test", type = "android" }
    alert_state.warn_called = false
    dash.select()
    assert(alert_state.warn_called == true)
  end)

  run("dashboard: select avd running sets active", function()
    local active_id
    package.loaded["anvim.devices"] = {
      list = function() return { { id = "emulator-5554", model = "sdk", status = "device" } } end,
      get_active = function() return nil end,
      set_active = function(id) active_id = id return true end,
    }
    package.loaded["anvim.emulator"] = {
      list_avds = function() return { "Pixel_6" } end,
      running_map = function() return { Pixel_6 = "emulator-5554" } end,
      launch = function() error("must not launch running avd") end,
    }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    dash.state.selected = 1
    dash.state.items = {
      { type = "avd", label = "Pixel_6 (emulator-5554)", avd = { name = "Pixel_6", running_id = "emulator-5554" } },
    }
    dash.state.proj = { name = "test", type = "android" }
    dash.select()
    assert(active_id == "emulator-5554", "got " .. tostring(active_id))
  end)

  run("dashboard: select avd stopped launches", function()
    local launched
    package.loaded["anvim.devices"] = {
      list = function() return {} end,
      get_active = function() return nil end,
      set_active = function() return true end,
    }
    package.loaded["anvim.emulator"] = {
      list_avds = function() return { "Pixel_6" } end,
      running_map = function() return {} end,
      launch = function(avd) launched = avd end,
    }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    dash.state.selected = 1
    dash.state.items = {
      { type = "avd", label = "Pixel_6 (stopped)", avd = { name = "Pixel_6", running_id = nil } },
    }
    dash.state.proj = { name = "test", type = "android" }
    dash.select()
    assert(launched == "Pixel_6", "got " .. tostring(launched))
    assert(dash.state.open == false, "dashboard harus close saat launch")
  end)

  run("dashboard: custom task select run_custom", function()
    local custom_called
    package.loaded["anvim.config"] = {
      get = function() return {
        dashboard = { width = 0.8, height = 0.8, border = "rounded", winblend = 10, min_width = 50, min_height = 14 },
        health_check = { tools = { "adb" }, auto = false },
        tasks = { custom = { { label = "Lint", cmd = { "echo", "lint" } } } },
      } end,
    }
    package.loaded["anvim.tasks"] = { run = function() end, stop = function() end,
      run_custom = function(cmd, label) custom_called = label end }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    local found = false
    for i, it in ipairs(dash.state.items) do
      if it.type == "custom" and it.label == "Lint" then
        dash.state.selected = i found = true break
      end
    end
    assert(found, "custom item harus ada")
    dash.select()
    assert(custom_called == "Lint", "got " .. tostring(custom_called))
    assert(dash.state.open == false)
  end)

  run("dashboard: do_test runs test task", function()
    local ran
    package.loaded["anvim.tasks"] = { run = function(_, task) ran = task end, stop = function() end, run_custom = function() end, rerun = function() return false end }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    dash.do_test()
    assert(ran == "test", "got " .. tostring(ran))
  end)

  run("dashboard: do_rerun closes on success", function()
    package.loaded["anvim.tasks"] = { run = function() end, stop = function() end, run_custom = function() end, rerun = function() return true end }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    dash.do_rerun()
    assert(dash.state.open == false)
  end)

  run("dashboard: scrcpy gantikan emulator bila ada", function()
    package.loaded["anvim.devices"] = {
      list = function() return { { id = "RF123", model = "Pixel", status = "device" } } end,
      get_active = function() return nil end,
      set_active = function() return true end,
    }
    package.loaded["anvim.scrcpy"] = {
      find_binary = function() return "/home/testuser/.anvim/tools/scrcpy/scrcpy" end,
      is_running = function() return false end,
    }
    package.loaded["anvim.emulator"] = {
      list_avds = function() return { "Pixel_6" } end,
      running_map = function() return {} end,
    }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    local has_scrcpy, has_emu = false, false
    for _, it in ipairs(dash.state.items) do
      if it.type == "scrcpy" then has_scrcpy = true end
      if it.type == "avd" or (it.type == "task" and it.task == "emulator") then has_emu = true end
    end
    assert(has_scrcpy == true, "section scrcpy harus ada")
    assert(has_emu == false, "section emulator harus disembunyikan")
  end)

  run("dashboard: emulator tampil bila scrcpy hilang", function()
    package.loaded["anvim.scrcpy"] = { find_binary = function() return nil end }
    package.loaded["anvim.emulator"] = {
      list_avds = function() return { "Pixel_6" } end,
      running_map = function() return {} end,
    }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    local has_emu = false
    for _, it in ipairs(dash.state.items) do
      if it.type == "avd" then has_emu = true end
    end
    assert(has_emu == true, "avd harus tampil tanpa scrcpy")
  end)

  run("dashboard: select scrcpy running stops", function()
    local stopped
    package.loaded["anvim.scrcpy"] = {
      find_binary = function() return "/x/scrcpy" end,
      is_running = function() return true end,
      stop = function(id) stopped = id end,
      launch = function() error("must not launch") end,
    }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = true; dash.state.buf = 11; dash.state.win = 22
    dash.state.items = {
      { type = "scrcpy", label = "x", scrcpy = { id = "RF123", running = true } },
    }
    dash.state.selected = 1
    dash.state.proj = { name = "test", type = "android" }
    dash.select()
    assert(stopped == "RF123", "got " .. tostring(stopped))
  end)

  run("dashboard: auto warn saat tool hilang", function()
    package.loaded["anvim.config"] = {
      get = function() return {
        dashboard = { width = 0.8, height = 0.8, border = "rounded", winblend = 10, min_width = 50, min_height = 14 },
        health_check = { tools = { "adb" }, auto = true },
        tasks = { custom = {} },
      } end,
    }
    package.loaded["anvim.system_check"] = {
      check_all = function() return {
        adb = { found = false, label = "ADB", status = "missing", hint = "install", optional = false },
      } end,
      format_line = function() return "✗ missing" end,
    }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    alert_state.warn_called = false
    dash.open()
    assert(alert_state.warn_called == true, "auto health harus warn")
  end)

  run("dashboard: open tahan walau section lambat error", function()
    package.loaded["anvim.emulator"] = {
      list_avds = function() error("boom") end,
      running_map = function() error("boom") end,
    }
    package.loaded["anvim.flutter"] = {
      list = function() error("boom") end,
    }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    assert(dash.state.open == true, "dashboard harus tetap terbuka")
    dash.close()
  end)

  run("dashboard: hint scrcpy bila belum install", function()
    package.loaded["anvim.devices"] = {
      list = function() return { { id = "RF123", model = "Pixel", status = "device" } } end,
      get_active = function() return nil end,
      set_active = function() return true end,
    }
    package.loaded["anvim.scrcpy"] = { find_binary = function() return nil end }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    local hint = false
    for _, it in ipairs(dash.state.items) do
      if it.type == "hint" and tostring(it.text):find("scrcpy") then hint = true end
    end
    assert(hint == true, "hint install scrcpy harus ada")
    dash.close()
  end)

  run("dashboard: hide emu+scrcpy bila tanpa device", function()
    package.loaded["anvim.devices"] = {
      list = function() return {} end,
      get_active = function() return nil end,
      set_active = function() return true end,
    }
    package.loaded["anvim.scrcpy"] = {
      find_binary = function() return "/x/scrcpy" end,
      is_running = function() return false end,
    }
    package.loaded["anvim.emulator"] = {
      list_avds = function() return { "Pixel_6" } end,
      running_map = function() return {} end,
    }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    for _, it in ipairs(dash.state.items) do
      assert(it.type ~= "scrcpy" and it.type ~= "avd", "emu/scrcpy harus hide tanpa device")
      if it.type == "task" then
        assert(it.task ~= "emulator" and it.task ~= "emulator_kill" and it.task ~= "scrcpy",
          "task emu/scrcpy harus hide")
      end
      if it.type == "header" then
        assert(it.text ~= "Emulators" and it.text ~= "Scrcpy", "header harus hide")
      end
    end
    dash.close()
  end)

  run("dashboard: node cek node + label npm", function()
    local got_tools
    package.loaded["anvim.system_check"] = {
      check_all = function(tools, _) got_tools = tools return {} end,
      format_line = function() return "x" end,
    }
    package.loaded["anvim.project"] = {
      detect = function() return { name = "web", type = "node", branch = "main", root = "/tmp/web", scripts = { dev = "x" } } end,
    }
    package.loaded["anvim.dashboard"] = nil
    dash = require("anvim.dashboard")
    dash.state.open = false; dash.state.buf = nil; dash.state.win = nil
    dash.open()
    local has_node = false
    for _, t in ipairs(got_tools) do if t == "node" then has_node = true end end
    assert(has_node == true, "node harus dicek: " .. table.concat(got_tools, ","))
    local label_ok = false
    for _, it in ipairs(dash.state.items) do
      if it.type == "task" and it.task == "run" and it.label:find("npm") then label_ok = true end
    end
    assert(label_ok == true, "label run harus npm")
    dash.close()
  end)
end
