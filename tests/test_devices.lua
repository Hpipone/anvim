-- test_devices.lua

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local function setup()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.system", function() return "List of devices attached\nemulator-5554\tdevice product:sdk model:Pixel_6\n" end)
    mock.raw("fn.expand", function(s) return (s:gsub("~", "/home/testuser")) end)
    mock.raw("fn.mkdir", function() end)
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() end, error = function() end, debug = function() end, ok = function() end }
    -- fake io.open agar tidak menyentuh home asli (persistensi)
    io.open = function(_, _)
      local store = io.__anvim_fake or ""
      return {
        write = function(_, s) io.__anvim_fake = s end,
        read = function() return (io.__anvim_fake or ""):gsub("\n$", "") end,
        close = function() end,
      }
    end
  end

  run("devices: parse normal + model dash/dot", function()
    setup()
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    local list = d.list()
    assert(#list == 1 and list[1].id == "emulator-5554", "got " .. #list)
    assert(list[1].model == "Pixel_6")
  end)

  run("devices: filter daemon + List header", function()
    setup()
    mock.raw("fn.system", function()
      return "List of devices attached\n* daemon started\nadb server version 41\nemulator-5554\tdevice\n\n"
    end)
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    local list = d.list()
    assert(#list == 1 and list[1].id == "emulator-5554", "got " .. #list)
  end)

  run("devices: model SM-G991B tidak unknown", function()
    setup()
    mock.raw("fn.system", function()
      return "List of devices attached\nR5CR11X\nabcd\tdevice product:x model:SM-G991B\n"
    end)
    -- baris di atas: pakai tab agar parse benar
    mock.raw("fn.system", function()
      return "List of devices attached\nABCD1234\tdevice product:x model:SM-G991B device:x\n"
    end)
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    local list = d.list()
    assert(list[1].model == "SM-G991B", "got " .. tostring(list[1].model))
  end)

  run("devices: set_active validasi", function()
    setup()
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    d.list()
    assert(d.set_active("emulator-5554") == true)
    assert(d.get_active() == "emulator-5554")
    assert(d.set_active("ngawur-999") == false)
  end)

  run("devices: device_args -s", function()
    setup()
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    d.list()
    d.set_active("emulator-5554")
    local a = d.device_args()
    assert(a[1] == "-s" and a[2] == "emulator-5554")
  end)

  run("devices: format full id (tidak potong 8)", function()
    setup()
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    local s = d.format({ id = "emulator-5554", model = "Pixel", status = "device" })
    assert(s:find("emulator%-5554"), "got " .. s)
  end)

  run("devices: set_active(nil) clear tanpa warn", function()
    setup()
    local warned = false
    package.loaded["anvim.status-alert"] = { info = function() end, warn = function() warned = true end, error = function() end, debug = function() end, ok = function() end }
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    d.list()
    d.set_active("emulator-5554")
    assert(d.set_active(nil) == true)
    assert(d.get_active() == nil)
    assert(warned == false, "clear tidak boleh warn")
  end)

  run("devices: active dipersist + restore saat list", function()
    setup()
    io.__anvim_fake = nil
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    d.list()
    d.set_active("emulator-5554")
    assert(io.__anvim_fake:find("emulator%-5554"), "harus tulis file")
    -- simulasi restart: modul fresh, state kosong
    package.loaded["anvim.devices"] = nil
    local d2 = require("anvim.devices")
    assert(d2.get_active() == nil)
    d2.list()
    assert(d2.get_active() == "emulator-5554", "harus restore, got " .. tostring(d2.get_active()))
  end)

  run("devices: adb_exec tambah -s active", function()
    setup()
    local got
    package.loaded["anvim.tasks"] = { run_custom = function(cmd) got = cmd end }
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    d.list()
    d.set_active("emulator-5554")
    d.adb_exec({ "shell", "getprop" }, {}, function() end)
    assert(got[1]:find("adb", 1, true) and got[2] == "-s" and got[3] == "emulator-5554" and got[4] == "shell",
      table.concat(got, " "))
  end)

  run("devices: adb_exec tanpa -s untuk connect", function()
    setup()
    local got
    package.loaded["anvim.tasks"] = { run_custom = function(cmd) got = cmd end }
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    d.list()
    d.set_active("emulator-5554")
    d.adb_exec({ "connect", "192.168.1.5:5555" }, {}, function() end)
    assert(#got == 3 and got[2] == "connect", table.concat(got, " "))
  end)

  run("devices: adb_pick connect validasi IP:port", function()
    setup()
    local got, warned = nil, false
    package.loaded["anvim.tasks"] = { run_custom = function(cmd) got = cmd end }
    package.loaded["anvim.status-alert"] = { info = function() end,
      warn = function() warned = true end, error = function() end, ok = function() end, debug = function() end }
    mock.raw("ui.select", function(_, _, cb) cb("connect (IP:port)…") end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    mock.raw("fn.input", function() return "ngawur" end)
    d.adb_pick(function() end)
    assert(warned == true and got == nil, "IP jelek harus ditolak")
    mock.raw("fn.input", function() return "192.168.1.5:5555" end)
    d.adb_pick(function() end)
    assert(got ~= nil and got[3] == "192.168.1.5:5555", "connect harus jalan")
  end)

  run("devices: adb_pick custom strip kata adb", function()
    setup()
    local got
    package.loaded["anvim.tasks"] = { run_custom = function(cmd) got = cmd end }
    mock.raw("ui.select", function(_, _, cb) cb("custom adb…") end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.input", function() return "adb shell wm size" end)
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    d.adb_pick(function() end)
    assert(got[1]:find("adb", 1, true) and got[2] == "shell", table.concat(got, " "))
  end)

  run("devices: adb pair kirim kode via chansend", function()
    setup()
    local captured = {}
    mock.raw("fn.jobstart", function(cmd, opts)
      captured.cmd = cmd
      captured.opts = opts
      return 21
    end)
    mock.raw("fn.chansend", function(id, data)
      assert(id == 21, "channel id harus job id (bukan nil!), got " .. tostring(id))
      captured.sent = { id = id, data = data }
      return 1
    end)
    mock.raw("fn.jobstop", function() end)
    mock.raw("schedule", function(fn) if type(fn) == "function" then fn() end end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.input", function() return "123456" end)
    local okmsg = nil
    package.loaded["anvim.status-alert"] = { info = function() end,
      warn = function() end, error = function() end, ok = function(m) okmsg = m end, debug = function() end }
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    local done = nil
    d.adb_pair("192.168.1.5:37099", function(ok) done = ok end)
    assert(captured.cmd[2] == "pair", "harus adb pair")
    captured.opts.on_stdout(nil, { "Enter pairing code: " })
    assert(captured.sent and captured.sent.data == "123456\n", "kode harus dikirim")
    captured.opts.on_exit(nil, 0)
    assert(done == true, "pair sukses")
    assert(okmsg and okmsg:find("Paired"), "notif paired, got " .. tostring(okmsg))
  end)

  run("devices: preset pair ada di toggle", function()
    setup()
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    local found = false
    for _, p in ipairs(d.ADB_PRESETS) do
      if p.cmd == "pair" then found = true end
    end
    assert(found == true, "preset pair wajib ada")
  end)

  run("devices: pair prompt terpotong chunk tetap ketemu", function()
    setup()
    local captured = {}
    mock.raw("fn.jobstart", function(_, opts)
      captured.opts = opts
      return 21
    end)
    mock.raw("fn.chansend", function(id, data)
      assert(id == 21, "channel id harus job id (bukan nil!), got " .. tostring(id))
      captured.sent = data
      return 1
    end)
    mock.raw("fn.jobstop", function() end)
    mock.raw("schedule", function(fn) if type(fn) == "function" then fn() end end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.input", function() return "654321" end)
    mock.raw("defer_fn", function() end)
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    local done = nil
    d.adb_pair("192.168.1.5:37099", function(ok) done = ok end)
    captured.opts.on_stdout(nil, { "Enter pair" })
    assert(captured.sent == nil, "chunk separuh jangan prompt")
    captured.opts.on_stdout(nil, { "ing code: " })
    assert(captured.sent == "654321\n", "kode harus dikirim, got " .. tostring(captured.sent))
    captured.opts.on_exit(nil, 0)
    assert(done == true)
  end)

  run("devices: pair prompt via stderr juga ketemu", function()
    setup()
    local captured = {}
    mock.raw("fn.jobstart", function(_, opts)
      captured.opts = opts
      return 21
    end)
    mock.raw("fn.chansend", function(id, data)
      assert(id == 21, "channel id harus job id (bukan nil!), got " .. tostring(id))
      captured.sent = data
      return 1
    end)
    mock.raw("fn.jobstop", function() end)
    mock.raw("schedule", function(fn) if type(fn) == "function" then fn() end end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.input", function() return "111222" end)
    mock.raw("defer_fn", function() end)
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    d.adb_pair("192.168.1.5:37099", function() end)
    captured.opts.on_stderr(nil, { "Enter pairing code: " })
    assert(captured.sent == "111222\n", "stderr harus dipantau")
  end)

  run("devices: pair kirim gagal lapor error asli", function()
    setup()
    local captured = {}
    local warns = {}
    mock.raw("fn.jobstart", function(_, opts)
      captured.opts = opts
      return 21
    end)
    mock.raw("fn.chansend", function() error("E900: Invalid channel id") end)
    mock.raw("fn.jobstop", function() end)
    mock.raw("schedule", function(fn) if type(fn) == "function" then fn() end end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.input", function() return "123456" end)
    mock.raw("defer_fn", function() end)
    package.loaded["anvim.status-alert"] = { info = function() end,
      warn = function(m) table.insert(warns, m) end, error = function() end, ok = function() end, debug = function() end }
    package.loaded["anvim.devices"] = nil
    local d = require("anvim.devices")
    local done = nil
    d.adb_pair("192.168.1.5:37099", function(ok) done = ok end)
    captured.opts.on_stderr(nil, { "error: protocol fault (timeout)" })
    captured.opts.on_stdout(nil, { "Enter pairing code: " })
    assert(done == false)
    local joined = table.concat(warns, "\n")
    assert(joined:find("protocol fault", 1, true), "harus tampilkan error adb: " .. joined)
    assert(not joined:find("channel closed", 1, true), "jangan salahkan channel: " .. joined)
  end)
end
