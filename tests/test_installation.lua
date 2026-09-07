-- test_installation.lua — unit tests for anvim/installation.lua (no-sudo model)

local function has_line(lines, pat)
  for _, l in ipairs(lines or {}) do
    if l:match(pat) then return true end
  end
  return false
end

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  local function base_mocks()
    mock.raw("uv.os_uname", function() return { sysname = "Linux", machine = "x86_64" } end)
    mock.raw("uv.now", function() return 10000 end)
    mock.raw("uv.fs_stat", function() return nil end)
    mock.raw("uv.new_timer", function() return { start = function() end, stop = function() end, close = function() end } end)
    mock.raw("fn.expand", function(s) return (s:gsub("~", "/home/testuser")) end)
    mock.raw("fn.shellescape", function(s) return "'" .. s .. "'" end)
    mock.raw("fn.mkdir", function() end)
    mock.raw("fn.glob", function() return {} end)
    mock.raw("fn.strftime", function() return "00:00:00" end)
    mock.raw("fn.strdisplaywidth", function(s) return #s end)
    mock.raw("fn.fnamemodify", function(p, _) return p end)
    mock.raw("fn.inputsave", function() end)
    mock.raw("fn.inputrestore", function() end)
    mock.raw("fn.input", function() return "" end)
    mock.raw("fn.isdirectory", function() return 1 end)
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
    mock.raw("env.SHELL", "/bin/bash")
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    mock.raw("keymap.set", function() end)
    mock.raw("defer_fn", function(fn, _) fn() end)
    package.loaded["anvim.config"] = {
      get = function()
        return { install = { strict_sha256 = false }, dashboard = {}, tasks = {}, logcat = {} }
      end,
    }
    package.loaded["anvim.keymaps.installation"] = { set = function() end }
  end

  run("deploy_binary: copy to local bin (no sudo)", function()
    base_mocks()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.system", function() return "" end)
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    local ok, deploy_logs = ins.deploy_binary(
      "/home/testuser/.anvim/tools/adb/platform-tools/adb", "adb",
      "/home/testuser/.anvim/tools/adb/platform-tools", {})
    assert(ok == true, "expected true, got " .. tostring(ok))
    assert(has_line(deploy_logs, "local/bin") or has_line(deploy_logs, "no sudo") or has_line(deploy_logs, "ready"),
      "expected local/bin log, got: " .. table.concat(deploy_logs, " | "))
  end)

  run("deploy_binary: rejects unsafe binary name", function()
    base_mocks()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.system", function() return "" end)
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    local ok, _ = ins.deploy_binary("/tmp/a;rm -rf /", "a;rm", "/tmp", {})
    assert(ok == false, "unsafe name must fail")
    local ok2, _ = ins.deploy_binary("/tmp/x", "a/b", "/tmp", {})
    assert(ok2 == false, "slash must fail")
  end)

  run("deploy_binary: shellescape dipakai untuk path spasi", function()
    base_mocks()
    local seen = {}
    mock.raw("fn.executable", function(name)
      if name == "my tool" then return 0 end
      return 1
    end)
    mock.raw("fn.system", function(cmd) table.insert(seen, tostring(cmd)); return "" end)
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    ins.deploy_binary("/home/u/my dir/adb", "adb", "/home/u/my dir", {})
    local joined = table.concat(seen, "\n")
    assert(joined:find("'") ~= nil, "expected shellescaped quote in: " .. joined)
  end)

  run("deploy_binary: Windows → no deploy", function()
    mock.raw("uv.os_uname", function() return { sysname = "Windows", machine = "x86_64" } end)
    base_mocks()
    package.loaded["anvim.util"] = nil
    package.loaded["anvim.installation"] = nil
    mock.raw("fn.executable", function() return 0 end)
    mock.raw("fn.system", function() return "" end)
    local ins = require("anvim.installation")
    local ok, _ = ins.deploy_binary("C:\\tools\\adb.exe", "adb.exe", "C:\\tools", {})
    assert(ok == false, "expected false on windows")
    package.loaded["anvim.util"] = nil
    package.loaded["anvim.installation"] = nil
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
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    assert(ins.get_total_size("https://example.com/file.zip") == 1048576)
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
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    assert(ins.get_total_size("https://example.com/file.zip") == 2097152)
  end)

  run("get_total_size: both fail → return 0", function()
    base_mocks()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.system", function() return "" end)
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    assert(ins.get_total_size("https://example.com/file.zip") == 0)
  end)

  run("verify_sha256: lolos dengan warning jika tanpa sha256_url", function()
    base_mocks()
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    local logs = {}
    local ok = ins.verify_sha256("/tmp/f.zip", { url = "https://x/y.zip" }, logs)
    assert(ok == true, "tanpa url harus lolos (warning saja)")
  end)

  run("verify_sha256: lolos jika download checksum gagal (best-effort)", function()
    base_mocks()
    mock.raw("fn.executable", function(name)
      if name == "curl" then return 0 end
      return 1
    end)
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    local logs = {}
    local ok = ins.verify_sha256("/tmp/f.zip", { url = "https://x/y.zip", sha256_url = "https://x/y.zip.sha256" }, logs)
    assert(ok == true, "checksum tak terjangkau harus lolos")
  end)

  run("install_tool: already in PATH → skip", function()
    base_mocks()
    mock.raw("fn.executable", function() return 1 end)
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    local called = false
    ins.install_tool("adb",
      { url = "https://example.com/adb.zip", file = "adb.zip", dir = "platform-tools" },
      "ADB", "adb", function(success) called = true assert(success == true) end)
    assert(called == true)
  end)

  run("install_tool: rejects unsafe bin_name", function()
    base_mocks()
    mock.raw("fn.executable", function() return 0 end)
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    local done
    ins.install_tool("x", { url = "https://e/x.zip", file = "x.zip" }, "X", "bad;name", function(s) done = s end)
    assert(done == false)
  end)

  run("install_tool: download fails → on_done(false)", function()
    base_mocks()
    mock.raw("fn.executable", function(name)
      if name == "adb" then return 0 end
      if name == "curl" then return 1 end
      return 0
    end)
    local job_cb
    mock.raw("fn.jobstart", function(_, opts) job_cb = opts.on_exit return 1 end)
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    local done_ok
    ins.install_tool("adb",
      { url = "https://example.com/adb.zip", file = "adb.zip", dir = "platform-tools" },
      "ADB", "adb", function(s) done_ok = s end)
    assert(job_cb ~= nil)
    job_cb(nil, 1)
    assert(done_ok == false)
  end)

  run("install_tool: download ok → on_done(true)", function()
    base_mocks()
    local cbs = {}
    local adb_calls = 0
    mock.raw("fn.executable", function(name)
      if name == "adb" then
        adb_calls = adb_calls + 1
        if adb_calls == 1 then return 0 end -- awal: belum ada → install jalan
        return 1 -- verify akhir: sudah ada
      end
      if name == "curl" then return 1 end
      if name == "unzip" then return 1 end
      if name == "sha256sum" or name == "shasum" then return 0 end
      return 1
    end)
    mock.raw("fn.jobstart", function(_, opts) table.insert(cbs, opts.on_exit) return 1 end)
    mock.raw("fn.system", function() return "" end)
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    local done_ok
    ins.install_tool("adb",
      { url = "https://example.com/adb.zip", file = "adb.zip", dir = "platform-tools" },
      "ADB", "adb", function(s) done_ok = s end)
    assert(#cbs >= 1)
    cbs[1](nil, 0)
    assert(#cbs >= 2, "extract job harus jalan")
    cbs[2](nil, 0)
    assert(done_ok == true, "on_done(true) expected, got " .. tostring(done_ok))
  end)

  run("deploy_binary: symlink preferred, copy fallback", function()
    base_mocks()
    local cmds = {}
    mock.raw("fn.system", function(cmd) table.insert(cmds, tostring(cmd)) return "" end)
    mock.raw("uv.fs_stat", function(p)
      if tostring(p):find("%.local/bin/adb") then return { type = "link" } end
      return nil
    end)
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    local ok, deploy_logs = ins.deploy_binary("/home/testuser/.anvim/tools/adb/platform-tools/adb", "adb",
      "/home/testuser/.anvim/tools/adb/platform-tools", {})
    assert(ok == true)
    assert(has_line(deploy_logs, "symlink"), "got: " .. table.concat(deploy_logs, " | "))
    assert(table.concat(cmds, "\n"):find("ln %-sfn"), "harus ln -sfn")
  end)

  run("deploy_binary: PATH hanya bin_dir (tanpa tools-dir)", function()
    base_mocks()
    mock.raw("fn.executable", function() return 1 end)
    mock.raw("fn.system", function() return "" end)
    mock.raw("env.PATH", "/usr/bin:/bin")
    package.loaded["anvim.installation"] = nil
    local ins = require("anvim.installation")
    ins.deploy_binary("/home/testuser/.anvim/tools/adb/platform-tools/adb", "adb",
      "/home/testuser/.anvim/tools/adb/platform-tools", {})
    assert(not vim.env.PATH:find("anvim/tools", 1, true), "tools-dir bocor: " .. vim.env.PATH)
    local bindir = "/home/testuser/.local/bin"
    assert(vim.env.PATH:sub(1, #bindir) == bindir, "got " .. vim.env.PATH)
  end)
end
