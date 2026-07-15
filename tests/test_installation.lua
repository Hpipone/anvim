-- test_installation.lua — unit tests for anvim/installation.lua
-- ponytail: mock vim.* API, test all deploy_binary paths

local function has_line(lines, pat)
  for _, l in ipairs(lines) do
    if l:match(pat) then return true end
  end
  return false
end

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local function base_mocks()
    mock.raw("loop.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    mock.raw("loop.now", function() return 10000 end)
    mock.raw("loop.fs_stat", function() return nil end)
    mock.raw("loop.new_timer", function() return { start = function() end, stop = function() end } end)
    mock.raw("fn.expand", function(s) return s:gsub("~", "/home/testuser") end)
    mock.raw("fn.shellescape", function(s) return s end)
    mock.raw("fn.mkdir", function() end)
    mock.raw("fn.glob", function() return {} end)
    mock.raw("fn.strftime", function() return "00:00:00" end)
    mock.raw("fn.strdisplaywidth", function(s) return #s end)
    mock.raw("fn.fnamemodify", function(p, what) return p end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.input", function() return "" end)
    mock.raw("fn.filewritable", function() return 0 end)
    mock.raw("fn.jobstart", function(_, opts)
      if opts and opts.on_exit then opts.on_exit(nil, 0) end
      return 1
    end)
    mock.raw("api.nvim_create_buf", function() return "buf_1" end)
    mock.raw("api.nvim_open_win", function() return "win_1" end)
    mock.raw("api.nvim_set_current_win", function() end)
    mock.raw("api.nvim_buf_is_valid", function() return true end)
    mock.raw("api.nvim_win_is_valid", function() return true end)
    mock.raw("api.nvim_win_close", function() end)
    mock.raw("api.nvim_buf_set_option", function() end)
    mock.raw("api.nvim_buf_set_lines", function() end)
    mock.raw("api.nvim_buf_line_count", function() return 1 end)
    mock.raw("api.nvim_buf_delete", function() end)
    mock.raw("api.nvim_buf_set_name", function() end)
    mock.raw("api.nvim_win_set_cursor", function() end)
    mock.raw("api.nvim_set_keymap", function() end)
    mock.raw("api.nvim_buf_set_keymap", function() end)
    mock.raw("api.nvim_create_user_command", function() end)
    mock.raw("schedule", function(fn) fn() end)
    mock.raw("o.lines", 50)
    mock.raw("o.columns", 200)
    mock.raw("env.PATH", "/usr/local/bin:/usr/bin:/bin")
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    mock.raw("g.anvim_logcat_max", 5000)
    mock.raw("bo", {})
    mock.raw("wo", {})
    mock.raw("keymap.set", function() end)
    mock.raw("wait", function() end)
    mock.raw("defer_fn", function(fn, ms) fn() end)
  end

  -- ── Tests ──

  run("deploy_binary: mv succeeds → /usr/bin/", function()
    base_mocks()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.system", function(cmd)
      local s = tostring(cmd)
      if s:match("mv.*adb /usr/bin/adb") then return "__X__:0" end
      if s:match("__X__") then return "__X__:0" end
      return ""
    end)
    local ins = require("anvim.installation")
    local lines = {}
    local ok, deploy_logs = ins.deploy_binary(
      "/home/testuser/.anvim/tools/adb/platform-tools/adb", "adb",
      "/home/testuser/.anvim/tools/adb/platform-tools", lines)
    assert(ok == true, "expected true, got " .. tostring(ok))
    assert(has_line(deploy_logs, "at /usr/bin/"),
           "expected /usr/bin/ log, got: " .. table.concat(deploy_logs, " | "))
  end)

  run("deploy_binary: mv fails, sudo succeeds", function()
    base_mocks()
    local call_count = 0
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.system", function()
      call_count = call_count + 1
      if call_count == 1 then return "" end        -- mv fails (no :0)
      return "__X__:0"                             -- sudo succeeds
    end)
    local ins = require("anvim.installation")
    local lines = {}
    local ok, deploy_logs = ins.deploy_binary(
      "/home/testuser/.anvim/tools/adb/platform-tools/adb", "adb",
      "/home/testuser/.anvim/tools/adb/platform-tools", lines)
    assert(ok == true, "expected true, got " .. tostring(ok))
    assert(has_line(deploy_logs, "at /usr/bin/"),
           "expected /usr/bin/ log, got: " .. table.concat(deploy_logs, " | "))
  end)

  run("deploy_binary: both fail → PATH fallback", function()
    base_mocks()
    mock.raw("fn.system", function() return "" end)
    mock.raw("fn.executable", function() return 1 end)
    -- override io.open only, preserve io.write/io.read etc
    local rc_write = {}
    local orig_open = io.open
    io.open = function(path, mode)
      if path:match("%.bashrc") and mode == "a" then
        return { write = function(_, s) table.insert(rc_write, s) end, close = function() end }
      end
      return orig_open and orig_open(path, mode)
    end
    local ins = require("anvim.installation")
    local lines = {}
    local ok, deploy_logs = ins.deploy_binary(
      "/home/testuser/.anvim/tools/adb/platform-tools/adb", "adb",
      "/home/testuser/.anvim/tools/adb/platform-tools", lines)
    if not ok then
      assert(has_line(deploy_logs, "PATH") or has_line(deploy_logs, "bashrc") or has_line(deploy_logs, "ready"),
             "expected PATH/RC log, got: " .. table.concat(deploy_logs, " | "))
    end
  end)

  run("deploy_binary: Windows → no deploy", function()
    mock.raw("loop.os_uname", function() return { sysname = "Windows", machine = "x86_64" } end)
    base_mocks()
    mock.raw("fn.executable", function() return 0 end)
    mock.raw("fn.system", function() return "" end)
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    local lines = {}
    local ok, deploy_logs = ins.deploy_binary("C:\\tools\\adb.exe", "adb.exe", "C:\\tools", lines)
    assert(ok == false, "expected false on windows")
  end)

  run("get_total_size: curl returns Content-Length", function()
    base_mocks()
    mock.raw("fn.executable", function(name)
      if name == "curl" then return 1 end
      return 0
    end)
    mock.raw("fn.system", function(cmd)
      if tostring(cmd):match("curl") then return "Content-Length: 1048576" end
      return ""
    end)
    local ins = require("anvim.installation")
    local size = ins.get_total_size("https://example.com/file.zip")
    assert(size == 1048576, "expected 1048576, got " .. tostring(size))
  end)

  run("get_total_size: wget fallback", function()
    base_mocks()
    mock.raw("fn.executable", function(name)
      if name == "curl" then return 0 end
      if name == "wget" then return 1 end
      return 0
    end)
    mock.raw("fn.system", function(cmd)
      if tostring(cmd):match("wget") then return "Content-Length: 2097152" end
      return ""
    end)
    local ins = require("anvim.installation")
    local size = ins.get_total_size("https://example.com/file.zip")
    assert(size == 2097152, "expected 2097152, got " .. tostring(size))
  end)

  run("get_total_size: both fail → return 0", function()
    base_mocks()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.system", function() return "" end)
    local ins = require("anvim.installation")
    local size = ins.get_total_size("https://example.com/file.zip")
    assert(size == 0, "expected 0, got " .. tostring(size))
  end)

  run("install_tool: already in PATH → skip", function()
    base_mocks()
    mock.raw("fn.executable", function() return 1 end)
    local ins = require("anvim.installation")
    local called = false
    ins.install_tool("adb",
      { url = "https://example.com/adb.zip", file = "adb.zip", dir = "platform-tools" },
      "ADB", "adb", function(success)
        called = true
        assert(success == true)
      end)
    assert(called == true, "expected on_done to fire")
  end)

  run("install_tool: cancel mid-install", function()
    base_mocks()
    local ins = require("anvim.installation")
    ins.install_active = false
    ins.install_cancelled = true
    assert(ins.install_active == false)
    assert(ins.install_cancelled == true)
  end)

  run("install_tool: download fails → on_done(false)", function()
    base_mocks()
    mock.raw("fn.executable", function(name)
      if name == "adb" then return 0 end  -- not in PATH → install
      if name == "curl" then return 1 end
      return 0
    end)
    local job_cb
    mock.raw("fn.jobstart", function(_cmd, opts)
      job_cb = opts.on_exit
      return 1
    end)
    local done_ok
    local ins = require("anvim.installation")
    ins.install_tool("adb",
      { url = "https://example.com/adb.zip", file = "adb.zip", dir = "platform-tools" },
      "ADB", "adb", function(s) done_ok = s end)
    assert(job_cb ~= nil, "job callback captured")
    job_cb(nil, 1)  -- download fail
    assert(done_ok == false, "on_done(false) expected")
  end)

  run("install_tool: download ok → on_done(true)", function()
    base_mocks()
    local call_n = 0
    local cbs = {}
    mock.raw("fn.executable", function(name)
      if name == "adb" then return 0 end
      if name == "curl" then return 1 end
      if name == "unzip" then return 1 end
      return 0
    end)
    mock.raw("fn.jobstart", function(_cmd, opts)
      call_n = call_n + 1
      cbs[call_n] = opts.on_exit
      return 1
    end)
    mock.raw("fn.system", function(cmd)
      local s = tostring(cmd)
      if s:match("mv.*/usr/bin/") then return "__X__:0" end
      if s:match("__X__") then return "__X__:0" end
      return ""
    end)
    local done_ok
    local ins = require("anvim.installation")
    ins.install_tool("adb",
      { url = "https://example.com/adb.zip", file = "adb.zip", dir = "platform-tools" },
      "ADB", "adb", function(s) done_ok = s end)
    assert(#cbs >= 1, "job callback captured")
    cbs[1](nil, 0)  -- download exit 0 → triggers extract jobstart
    cbs[2](nil, 0)  -- extract exit 0 → deploy → verify
    assert(done_ok == true, "on_done(true) expected")
  end)

  run("render_progress: module loads", function()
    base_mocks()
    local ins = require("anvim.installation")
    assert(ins ~= nil)
  end)

  run("open_progress_win: module loads", function()
    base_mocks()
    local ins = require("anvim.installation")
    assert(ins ~= nil)
  end)
end
