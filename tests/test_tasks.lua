-- test_tasks.lua

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local function setup()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.getcwd", function() return "/tmp/proj" end)
    mock.raw("fn.isdirectory", function() return 1 end)
    mock.raw("fn.setqflist", function() end)
    mock.raw("fn.jobstart", function(_, opts)
      if opts and opts.on_exit then opts.on_exit(nil, 0) end
      return 5
    end)
    mock.raw("api.nvim_create_buf", function() return 51 end)
    mock.raw("api.nvim_open_win", function() return 52 end)
    mock.raw("api.nvim_buf_is_valid", function() return true end)
    mock.raw("api.nvim_win_is_valid", function() return true end)
    mock.raw("api.nvim_buf_set_lines", function() end)
    mock.raw("api.nvim_buf_line_count", function() return 3 end)
    mock.raw("api.nvim_buf_set_name", function() end)
    mock.raw("uv.new_timer", function() return { start = function() end, stop = function() end, close = function() end } end)
    mock.raw("schedule", function(fn) if type(fn) == "function" then fn() end end)
    mock.raw("o.columns", 200)
    mock.raw("o.lines", 50)
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, ok = function() end }
    package.loaded["anvim.devices"] = { get_active = function() return "emulator-5554" end }
    package.loaded["anvim.config"] = { get = function() return { tasks = { timeout_ms = 300000 } } end }
    package.loaded["anvim.util"] = nil
  end

  run("tasks: cmd flutter run pakai -d device", function()
    setup()
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local cmd = t._cmd_for({ type = "flutter", build_tool = "flutter" }, "run")
    assert(cmd[1] == "flutter" and cmd[3] == "-d", table.concat(cmd, " "))
  end)

  run("tasks: gradlew tanpa exec fallback gradle", function()
    setup()
    mock.raw("fn.executable", function(name)
      if name == "gradle" then return 1 end
      return 0
    end)
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local cmd = t._cmd_for({ type = "android", build_tool = "/proj/gradlew" }, "build")
    assert(cmd[1] == "gradle", table.concat(cmd, " "))
  end)

  run("tasks: run sukses on_done(true)", function()
    setup()
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local ok_v
    t.run({ type = "flutter", build_tool = "flutter", root = "/tmp/proj" }, "clean", function(_, ok) ok_v = ok end)
    assert(ok_v == true)
  end)

  run("tasks: run android sukses auto-launch monkey", function()
    setup()
    local launched = nil
    mock.raw("fn.jobstart", function(cmd, opts)
      if tostring(cmd[1]):find("gradle") then
        if opts and opts.on_exit then opts.on_exit(nil, 0) end
        return 5
      end
      launched = cmd
      if opts and opts.on_exit then opts.on_exit(nil, 0) end
      return 6
    end)
    package.loaded["anvim.devices"] = { get_active = function() return "emulator-5554" end }
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local ok_v
    t.run({ type = "android", build_tool = "gradle", root = "/tmp/proj", package = "com.test.app" }, "run",
      function(_, ok) ok_v = ok end)
    assert(ok_v == true)
    assert(launched ~= nil, "monkey harus jalan")
    local j = table.concat(launched, " ")
    assert(j:find("monkey", 1, true) and j:find("com.test.app", 1, true), "got: " .. j)
    assert(j:find("emulator-5554", 1, true) or j:find("-s", 1, true),
      "device harus diteruskan: " .. j)
  end)

  run("tasks: run android tanpa package tetap sukses", function()
    setup()
    local launched = false
    mock.raw("fn.jobstart", function(_, opts)
      if opts and opts.on_exit then opts.on_exit(nil, 0) end
      launched = true
      return 5
    end)
    package.loaded["anvim.devices"] = { get_active = function() return nil end }
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local ok_v
    t.run({ type = "android", build_tool = "gradle", root = "/tmp/proj", package = nil }, "run",
      function(_, ok) ok_v = ok end)
    assert(ok_v == true, "install sukses walau tanpa launch")
  end)

  run("tasks: tolak jika binary hilang", function()
    setup()
    mock.raw("fn.executable", function() return 0 end)
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local ok_v = nil
    t.run({ type = "flutter", build_tool = "flutter", root = "/tmp/proj" }, "clean", function(_, ok) ok_v = ok end)
    assert(ok_v == false)
  end)

  run("tasks: guard single running + stop", function()
    setup()
    mock.raw("fn.jobstart", function() return 5 end)
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    t.state.running = true
    t.state.current = "run"
    local called = false
    t.run({ type = "flutter", build_tool = "flutter", root = "/tmp" }, "clean", function() called = true end)
    assert(called == false, "harus ditolak saat running")
    t.stop()
    assert(t.state.running == false)
  end)

  run("tasks: cmd test flutter + android", function()
    setup()
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local f = t._cmd_for({ type = "flutter", build_tool = "flutter" }, "test")
    assert(f[1] == "flutter" and f[2] == "test", table.concat(f, " "))
    local a = t._cmd_for({ type = "android", build_tool = "gradle" }, "test")
    assert(a[2] == "test", table.concat(a, " "))
  end)

  run("tasks: run_custom sukses", function()
    setup()
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local ok_v
    t.run_custom({ "echo", "hi" }, "echo-hi", function(_, ok) ok_v = ok end)
    assert(ok_v == true)
  end)

  run("tasks: run_custom tolak cmd invalid", function()
    setup()
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local ok_v = nil
    t.run_custom({}, "empty", function(_, ok) ok_v = ok end)
    assert(ok_v == false)
    t.run_custom("bukan-table", "x", function(_, ok) ok_v = ok end)
    assert(ok_v == false)
  end)

  run("tasks: run_custom tolak binary hilang", function()
    setup()
    mock.raw("fn.executable", function() return 0 end)
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local ok_v = nil
    t.run_custom({ "ngawur-bin", "--x" }, "x", function(_, ok) ok_v = ok end)
    assert(ok_v == false)
  end)

  run("tasks: rerun false jika belum ada", function()
    setup()
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    assert(t.rerun() == false)
  end)

  run("tasks: rerun custom terakhir", function()
    setup()
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local n = 0
    t.run_custom({ "echo", "a" }, "ea", function() n = n + 1 end)
    assert(t.rerun(function() n = n + 1 end) == true)
    assert(n == 2, "rerun harus jalan lagi, got " .. n)
  end)

  run("tasks: rerun named detect ulang", function()
    setup()
    package.loaded["anvim.project"] = {
      detect = function() return { type = "flutter", build_tool = "flutter", root = "/tmp/proj" } end,
    }
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    t.run({ type = "flutter", build_tool = "flutter", root = "/tmp/proj" }, "clean")
    assert(t.state.last.task == "clean")
    assert(t.state.last.project.root == "/tmp/proj", "snapshot root harus tersimpan")
    assert(t.rerun() == true)
  end)

  run("tasks: rerun pakai snapshot walau cwd pindah", function()
    setup()
    local got_cwd
    mock.raw("fn.jobstart", function(_, opts)
      got_cwd = opts.cwd
      if opts and opts.on_exit then opts.on_exit(nil, 0) end
      return 5
    end)
    mock.raw("fn.getcwd", function() return "/tmp/proj" end)
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    t.run({ type = "flutter", build_tool = "flutter", root = "/tmp/proj" }, "clean")
    mock.raw("fn.getcwd", function() return "/tmp/lain" end)
    assert(t.rerun() == true)
    assert(got_cwd == "/tmp/proj", "rerun harus pakai snapshot root, got " .. tostring(got_cwd))
  end)

  run("tasks: flutter id tak dikenal warn tapi jalan", function()
    setup()
    local warned = false
    package.loaded["anvim.status-alert"] = { info = function() end,
      warn = function() warned = true end, error = function() end, ok = function() end }
    package.loaded["anvim.flutter"] = { list = function() return { { id = "lain" } } end }
    package.loaded["anvim.devices"] = { get_active = function() return "emulator-5554" end }
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local cmd = t._cmd_for({ type = "flutter", build_tool = "flutter" }, "run")
    assert(cmd[4] == "emulator-5554", table.concat(cmd, " "))
    assert(warned == true, "harus warn namespace beda")
  end)

  run("tasks: gradle teruskan ANDROID_SERIAL", function()
    setup()
    local got_env
    mock.raw("fn.jobstart", function(_, opts)
      got_env = opts.env
      if opts and opts.on_exit then opts.on_exit(nil, 0) end
      return 5
    end)
    package.loaded["anvim.devices"] = { get_active = function() return "RF123" end }
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    t.run({ type = "android", build_tool = "gradle", root = "/tmp/proj" }, "build")
    assert(got_env and got_env.ANDROID_SERIAL == "RF123", "ANDROID_SERIAL hilang")
  end)

  run("tasks: on_exit basi setelah cancel diabaikan", function()
    setup()
    local exit_cb
    mock.raw("fn.jobstart", function(_, opts) exit_cb = opts.on_exit return 5 end)
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local n = 0
    t.run({ type = "flutter", build_tool = "flutter", root = "/tmp/proj" }, "clean", function() n = n + 1 end)
    t.stop() -- cancel: gen naik
    exit_cb(nil, 1) -- on_exit telat dari job mati
    assert(n == 0, "callback basi harus diabaikan, got " .. n)
  end)

  run("tasks: cmd node pakai npm scripts", function()
    setup()
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    local proj = { type = "node", build_tool = "npm", root = "/tmp/app", scripts = { dev = "expo start", build = "expo build", test = "jest", clean = "rm" } }
    local r = t._cmd_for(proj, "run")
    assert(r[1] == "npm" and r[3] == "dev", table.concat(r, " "))
    local b = t._cmd_for(proj, "build")
    assert(b[3] == "build", table.concat(b, " "))
    local te = t._cmd_for(proj, "test")
    assert(te[1] == "npm" and te[2] == "test", table.concat(te, " "))
    local bare = { type = "node", build_tool = "npm", root = "/tmp/app", scripts = {} }
    assert(t._cmd_for(bare, "run") == nil, "tanpa script dev/start harus nil")
    assert(t._cmd_for(bare, "build") == nil)
  end)

  run("tasks: output di depan (zindex) + bisa ditutup", function()
    setup()
    local win_cfg, win_enter
    mock.raw("api.nvim_open_win", function(_, enter, cfg) win_cfg = cfg win_enter = enter return 52 end)
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    t.run({ type = "flutter", build_tool = "flutter", root = "/tmp/proj" }, "clean")
    assert(win_cfg and (win_cfg.zindex or 0) > 0, "output harus di depan")
    assert(win_enter == true, "cursor harus ke task window")
    t.state.win = 52
    t.close_output()
    assert(t.state.win == nil)
  end)

  run("tasks: close_output kembali ke dashboard", function()
    setup()
    local opened = false
    package.loaded["anvim.dashboard"] = { state = { open = false }, open = function() opened = true end }
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    t.state.win = nil
    t.close_output()
    assert(opened == true, "tutup output harus buka dashboard")
  end)

  run("tasks: tanpa log done di buffer", function()
    setup()
    local appended = {}
    mock.raw("api.nvim_buf_set_lines", function(_, _, _, _, lines)
      for _, l in ipairs(lines or {}) do table.insert(appended, l) end
    end)
    package.loaded["anvim.tasks"] = nil
    local t = require("anvim.tasks")
    t.run({ type = "flutter", build_tool = "flutter", root = "/tmp/proj" }, "clean")
    for _, l in ipairs(appended) do
      assert(not l:find("done:", 1, true), "log done harus hilang: " .. l)
    end
  end)
end
