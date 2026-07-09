-- anvim: help_check — auto-detect OS, cek path, download tool yg missing
-- ponytail: multi-select, single progress bar, ESC-only close

local M = {}
M.results = {}
M.downloading = false
M.install_active = false
M.phase = ""

-- ── OS detection ──────────────────────────────────────────
local function os_type()
  local uname = vim.loop.os_uname()
  local sysname = uname.sysname:lower()
  if sysname:find("windows") or sysname:find("win32") then return "windows" end
  if sysname:find("darwin") then return "macos" end
  return "linux"
end

local function os_arch()
  local uname = vim.loop.os_uname()
  local m = uname.machine:lower()
  if m == "aarch64" or m == "arm64" then return "arm64" end
  if m == "x86_64" or m == "amd64" then return "x86_64" end
  return m
end

local OS = os_type()
local ARCH = os_arch()

-- ── tool definitions ──────────────────────────────────────
local TOOLS = {
  adb = {
    label = "ADB",
    desc = "Android Debug Bridge — komunikasi dgn device Android",
    check_paths = {
      linux   = { "adb", "~/Android/Sdk/platform-tools/adb", "~/android/platform-tools/adb", "/usr/bin/adb", "/usr/local/bin/adb" },
      macos   = { "adb", "~/Android/Sdk/platform-tools/adb", "~/Library/Android/sdk/platform-tools/adb", "/usr/local/bin/adb" },
      windows = { "adb.exe", "~/AppData/Local/Android/Sdk/platform-tools/adb.exe", "C:\\Android\\platform-tools\\adb.exe" },
    },
    download = {
      linux   = { url = "https://dl.google.com/android/repository/platform-tools-latest-linux.zip", file = "platform-tools-latest-linux.zip", dir = "platform-tools" },
      macos   = { url = "https://dl.google.com/android/repository/platform-tools-latest-darwin.zip", file = "platform-tools-latest-darwin.zip", dir = "platform-tools" },
      windows = { url = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip", file = "platform-tools-latest-windows.zip", dir = "platform-tools" },
    },
    post_msg = "Tambahkan direktori platform-tools ke PATH atau set ANDROID_HOME.",
  },
  java = {
    label = "Java",
    desc = "Java Runtime — dibutuhkan Gradle build Android",
    check_paths = {
      linux   = { "java", "/usr/bin/java", "/usr/lib/jvm/*/bin/java" },
      macos   = { "java", "/usr/bin/java", "/Library/Java/JavaVirtualMachines/*/Contents/Home/bin/java" },
      windows = { "java.exe", "C:\\Program Files\\Java\\*\\bin\\java.exe", "C:\\Program Files (x86)\\Java\\*\\bin\\java.exe" },
    },
    download = nil,
    post_msg = "Install Java: https://adoptium.net — Pilih Temurin JDK 17+ untuk OS kamu.",
  },
  flutter = {
    label = "Flutter",
    desc = "Flutter SDK — framework UI multiplatform",
    check_paths = {
      linux   = { "flutter", "~/flutter/bin/flutter", "/usr/local/flutter/bin/flutter", "/opt/flutter/bin/flutter" },
      macos   = { "flutter", "~/flutter/bin/flutter", "/usr/local/flutter/bin/flutter", "/opt/homebrew/bin/flutter" },
      windows = { "flutter.exe", "~/flutter/bin/flutter.exe", "C:\\flutter\\bin\\flutter.exe" },
    },
    download = {
      linux   = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.29.2-stable.tar.xz", file = "flutter.tar.xz", dir = "flutter" },
      macos   = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.29.2-stable.zip", file = "flutter.zip", dir = "flutter" },
      windows = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.29.2-stable.zip", file = "flutter.zip", dir = "flutter" },
    },
    post_msg = "Tambahkan flutter/bin ke PATH. Jalankan 'flutter doctor' setelah install.",
  },
  git = {
    label = "Git",
    desc = "Version control — info branch & project versioning",
    check_paths = {
      linux   = { "git", "/usr/bin/git", "/usr/local/bin/git" },
      macos   = { "git", "/usr/bin/git", "/usr/local/bin/git" },
      windows = { "git.exe", "C:\\Program Files\\Git\\bin\\git.exe" },
    },
    download = nil,
    post_msg = "Install Git: https://git-scm.com/download/" .. os_type(),
  },
  gradle = {
    label = "Gradle",
    desc = "Build tool Android — cek project pakai gradlew dulu",
    check_paths = {
      linux   = { "gradle", "/usr/bin/gradle", "/usr/local/bin/gradle" },
      macos   = { "gradle", "/usr/bin/gradle", "/usr/local/bin/gradle" },
      windows = { "gradle.exe", "C:\\Gradle\\bin\\gradle.exe" },
    },
    download = {
      linux   = { url = "https://services.gradle.org/distributions/gradle-8.10.2-bin.zip", file = "gradle.zip", dir = "gradle-8.10.2" },
      macos   = { url = "https://services.gradle.org/distributions/gradle-8.10.2-bin.zip", file = "gradle.zip", dir = "gradle-8.10.2" },
      windows = { url = "https://services.gradle.org/distributions/gradle-8.10.2-bin.zip", file = "gradle.zip", dir = "gradle-8.10.2" },
    },
    post_msg = "Tambahkan gradle/bin ke PATH atau pakai gradlew project.",
  },
}

-- ── cari binary ──────────────────────────────────────────
local function find_tool(name)
  local spec = TOOLS[name]
  if not spec then return nil end

  local exe = vim.fn.exepath(spec.check_paths[OS][1])
  if exe and exe ~= "" then
    return { found = true, path = exe, method = "PATH" }
  end

  for _, p in ipairs(spec.check_paths[OS]) do
    if not p:find("*") then
      local expanded = vim.fn.expand(p)
      if vim.fn.executable(expanded) == 1 then
        return { found = true, path = expanded, method = "common path" }
      end
    else
      local matches = vim.fn.glob(p, false, true)
      if #matches > 0 then
        local expanded = vim.fn.expand(matches[1])
        if vim.fn.executable(expanded) == 1 then
          return { found = true, path = expanded, method = "wildcard" }
        end
      end
    end
  end

  if name == "adb" then
    local ah = vim.env.ANDROID_HOME or vim.env.ANDROID_SDK_ROOT
    if ah then
      local cands = { ah .. "/platform-tools/adb", ah .. "\\platform-tools\\adb.exe" }
      for _, p in ipairs(cands) do
        local e = vim.fn.expand(p)
        if vim.fn.executable(e) == 1 then
          return { found = true, path = e, method = "ANDROID_HOME" }
        end
      end
    end
  end

  return { found = false, path = nil, method = nil }
end

-- ── public check ──────────────────────────────────────────
function M.check_tool(name)
  local spec = TOOLS[name]
  if not spec then return { found = false, label = name } end
  local result = find_tool(name)
  result.label = spec.label
  result.desc = spec.desc
  result.can_download = spec.download ~= nil
  result.name = name
  M.results[name] = result
  return result
end

function M.check_all(only)
  M.results = {}
  local list = only or { "adb", "java", "flutter", "git", "gradle" }
  for _, name in ipairs(list) do
    M.check_tool(name)
  end
  return M.results
end

function M.get_missing()
  local missing = {}
  for name, r in pairs(M.results) do
    if not r.found then
      table.insert(missing, name)
    end
  end
  return missing
end

-- ── format output ─────────────────────────────────────────
function M.format_one(name, r)
  local icon = r.found and " ✓" or " ✗"
  local label = r.label or name
  if r.found then
    return icon .. " " .. label .. " — " .. r.path
  end
  return icon .. " " .. label .. " — TIDAK DITEMUKAN"
end

function M.format_report()
  local lines = {}
  table.insert(lines, "")
  table.insert(lines, "╭───── anvim System Check ─────────────────────────────╮")
  table.insert(lines, "│ OS: " .. string.format("%-10s", OS:upper()) .. " Arch: " .. ARCH .. "                   │")

  local ok, missing = 0, 0
  for name, r in pairs(M.results) do
    local icon = r.found and " ✓" or " ✗"
    local label = r.label or name
    if r.found then
      ok = ok + 1
      local path = r.path:len() > 40 and "..." .. r.path:sub(-37) or r.path
      table.insert(lines, "│" .. icon .. " " .. string.format("%-10s", label) .. path .. string.rep(" ", 16) .. "│")
    else
      missing = missing + 1
      table.insert(lines, "│" .. icon .. " " .. string.format("%-10s", label) .. "tidak ditemukan" .. string.rep(" ", 17) .. "│")
    end
  end

  table.insert(lines, "├───────────────────────────────────────────────────────┤")
  local status = (missing == 0) and "✅ SEMUA BAIK" or ("⚠️  " .. missing .. " tool belum terinstall")
  table.insert(lines, "│ " .. status .. string.rep(" ", 42 - #status) .. "│")
  table.insert(lines, "╰───────────────────────────────────────────────────────╯")
  table.insert(lines, "")

  return table.concat(lines, "\n")
end

-- ── progress window ──────────────────────────────────────
local function fmt_size(bytes)
  if bytes < 1024 then return string.format("%.0f B", bytes) end
  if bytes < 1024*1024 then return string.format("%.1f KB", bytes/1024) end
  if bytes < 1024*1024*1024 then return string.format("%.1f MB", bytes/(1024*1024)) end
  return string.format("%.2f GB", bytes/(1024*1024*1024))
end

local function fmt_time(secs)
  if secs <= 0 then return "--:--:--" end
  local h = math.floor(secs/3600)
  local m = math.floor((secs%3600)/60)
  local s = math.floor(secs%60)
  return string.format("%02d:%02d:%02d", h, m, s)
end

local function fmt_speed(bytes_per_sec)
  if bytes_per_sec < 1024 then return string.format("%.0f B/s", bytes_per_sec) end
  if bytes_per_sec < 1024*1024 then return string.format("%.1f KB/s", bytes_per_sec/1024) end
  return string.format("%.1f MB/s", bytes_per_sec/(1024*1024))
end

local BAR_WIDTH = 30

local function render_progress_win(buf, phase, pct, speed, eta, logs)
  pct = math.min(100, math.max(0, pct))
  local filled = math.floor(pct/100 * BAR_WIDTH)
  local empty = BAR_WIDTH - filled
  local bar = "[" .. string.rep("■", filled) .. string.rep("□", empty) .. "]"
  local pct_s = string.format("%5.1f%%", pct)
  local spd_s = fmt_speed(speed)
  local eta_s = fmt_time(eta)

  local lines = {
    "",
    "  " .. phase,
    "",
    "  " .. bar .. "  " .. pct_s,
    "  Speed: " .. spd_s .. "    ETA: " .. eta_s,
    "",
  }

  local max_log = 20
  local start = math.max(1, #logs - max_log + 1)
  for i = start, #logs do
    table.insert(lines, "  > " .. logs[i])
  end

  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

-- ── single install flow: download → extract → check → done ──
local function get_total_size(url)
  if vim.fn.executable("curl") ~= 1 then return 0 end
  local ok, out = pcall(vim.fn.system, "curl -sIkL " .. vim.fn.shellescape(url) .. " 2>/dev/null")
  if not ok or out == "" then return 0 end
  local len = out:match("[Cc]ontent-[Ll]ength:%s*(%d+)")
  return tonumber(len) or 0
end

function M.install_tool(name, on_done)
  local spec = TOOLS[name]
  if not spec or not spec.download then
    vim.notify("[anvim] " .. name .. " tidak support auto-download.", vim.log.levels.WARN)
    if on_done then on_done(false) end
    return
  end

  local dl = spec.download[OS]
  if not dl then
    vim.notify("[anvim] Belum ada download untuk OS " .. OS, vim.log.levels.WARN)
    if on_done then on_done(false) end
    return
  end

  local homedir = vim.fn.expand("~")
  local dest = homedir .. "/.anvim/tools/" .. name
  vim.fn.mkdir(dest, "p")
  local zip_path = dest .. "/" .. dl.file
  local total = get_total_size(dl.url)

  local logs = {}
  local start_time = vim.loop.now()
  M.install_active = true
  M.phase = "Memulai instalasi " .. spec.label .. "..."

  -- progress window
  local pw_buf = vim.api.nvim_create_buf(false, true)
  local pw_win = vim.api.nvim_open_win(pw_buf, true, {
    relative = "editor", width = 60, height = 18,
    col = math.floor((vim.o.columns - 60) / 2),
    row = math.floor((vim.o.lines - 18) / 2),
    style = "minimal", border = "rounded",
    title = " Install " .. spec.label .. " ",
    title_pos = "center",
  })

  -- ESC-only close
  vim.api.nvim_buf_set_keymap(pw_buf, "n", "<Esc>", "", {
    nowait = true, silent = true,
    callback = function()
      if not M.install_active then
        vim.api.nvim_buf_delete(pw_buf, { force = true })
      end
    end,
  })

  -- state
  local last_bytes = 0
  local last_time = start_time
  local speed = 0
  local timer
  local function stop_timer()
    if timer then timer:stop(); timer = nil end
  end
  local function redraw()
    render_progress_win(pw_buf, M.phase, 0, 0, 0, logs)
  end

  timer = vim.loop.new_timer()
  timer:start(0, 200, vim.schedule_wrap(function()
    if not M.install_active then
      stop_timer()
      return
    end
    local info = vim.loop.fs_stat(zip_path)
    local downloaded = info and info.size or 0
    local now = vim.loop.now()
    local dt = (now - last_time) / 1000
    if dt > 0 then
      speed = (speed * 0.7) + ((downloaded - last_bytes) / dt * 0.3)
    end
    last_bytes = downloaded
    last_time = now
    local pct = total > 0 and (downloaded / total * 100) or 0
    local eta = speed > 0 and total > 0 and ((total - downloaded) / speed) or 0
    render_progress_win(pw_buf, M.phase, pct, speed, eta, logs)
  end))

  local function close_pw()
    stop_timer()
    M.install_active = false
    if pw_buf and vim.api.nvim_buf_is_valid(pw_buf) then
      vim.api.nvim_buf_delete(pw_buf, { force = true })
    end
  end

  -- ── PHASE 1: download ──
  M.phase = "Download " .. spec.label .. "..."

  local cmd
  if vim.fn.executable("curl") == 1 then
    cmd = { "curl", "-L", "-o", zip_path, dl.url }
  elseif vim.fn.executable("wget") == 1 then
    cmd = { "wget", "-O", zip_path, dl.url }
  else
    table.insert(logs, "ERROR: butuh curl atau wget")
    redraw()
    vim.wait(2000)
    close_pw()
    if on_done then on_done(false) end
    return
  end

  table.insert(logs, "Mulai download dari server...")
  redraw()

  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if not M.install_active then return end

      if code ~= 0 then
        table.insert(logs, "Download gagal (exit " .. code .. ")")
        redraw()
        vim.wait(2000)
        close_pw()
        if on_done then on_done(false) end
        return
      end

      table.insert(logs, "Download selesai (" .. fmt_size(total) .. ")")
      redraw()

      -- ── PHASE 2: extract ──
      if M.install_active then
        M.phase = "Extract " .. spec.label .. "..."
        table.insert(logs, "Mulai ekstrak...")
        redraw()

        local extract_cmd
        local extract_dir = dest .. "/extracted"
        vim.fn.mkdir(extract_dir, "p")

        if zip_path:match("%.zip$") then
          if vim.fn.executable("unzip") == 1 then
            extract_cmd = { "unzip", "-o", zip_path, "-d", extract_dir }
          end
        elseif zip_path:match("%.tar%.xz$") or zip_path:match("%.tar%.gz$") or zip_path:match("%.tgz$") then
          if vim.fn.executable("tar") == 1 then
            extract_cmd = { "tar", "-xf", zip_path, "-C", extract_dir }
          end
        end

        if not extract_cmd then
          table.insert(logs, "Extract manual: " .. zip_path)
          redraw()
          close_pw()
          if on_done then on_done(false) end
          return
        end

        table.insert(logs, "Menjalankan: " .. table.concat(extract_cmd, " "))
        redraw()

        vim.fn.jobstart(extract_cmd, {
          on_exit = function(_, ecode)
            if not M.install_active then return end

            if ecode ~= 0 then
              table.insert(logs, "Ekstrak gagal (exit " .. ecode .. ")")
              redraw()
              vim.wait(2000)
              close_pw()
              if on_done then on_done(false) end
              return
            end

            table.insert(logs, "Ekstrak berhasil")
            table.insert(logs, "Menyusun file...")

            -- cari binary
            local bin_name = (OS == "windows") and (name .. ".exe") or name
            local found_path = vim.fn.glob(extract_dir .. "/**/" .. bin_name, false, true)
            local final_path
            if #found_path > 0 then
              final_path = vim.fn.fnamemodify(found_path[1], ":h")
            else
              final_path = extract_dir
            end

            -- pindahin ke dest
            if OS == "windows" then
              vim.fn.system("move " .. extract_dir .. "\\* " .. dest .. "\\")
            else
              vim.fn.system("cp -r " .. extract_dir .. "/* " .. dest .. "/")
            end
            pcall(os.remove, zip_path)
            pcall(function() vim.fn.system("rm -rf " .. extract_dir) end)
            table.insert(logs, "Tool terinstall di: " .. dest)
            redraw()

            -- ── PHASE 3: system cek ──
            if M.install_active then
              M.phase = "System check..."
              table.insert(logs, "Verifikasi instalasi...")
              redraw()

              -- update PATH
              if not vim.env.PATH:find(dest) then
                vim.env.PATH = dest .. ":" .. vim.env.PATH
              end

              -- re-check
              local exe = (OS == "windows") and (name .. ".exe") or name
              if vim.fn.executable(exe) == 1 then
                table.insert(logs, "✓ " .. spec.label .. " siap digunakan!")
              else
                table.insert(logs, "⚠ " .. spec.label .. " terinstall tapi PATH perlu diatur manual")
              end
              redraw()

              -- ── PHASE 4: selesai ──
              M.phase = "Instalasi selesai! ✓"
              table.insert(logs, "Tekan ESC untuk tutup")
              stop_timer()

              -- render final statis
              render_progress_win(pw_buf, M.phase, 100, 0, 0, logs)
              M.install_active = false
              vim.wait(1500)

              -- close window sebelum lanjut tool berikutnya
              close_pw()
              if on_done then on_done(true) end
            end
          end,
        })
      end
    end,
  })
end

-- ── interactive check + multi-select download ────────────
function M.interactive()
  M.check_all()
  print(M.format_report())

  local missing = M.get_missing()
  if #missing == 0 then
    print("🎉 Semua tool terdeteksi. Tidak perlu download apapun.")
    return
  end

  print("")
  print("⚠️  Beberapa tool tidak ditemukan.")
  print("")

  local downloadables = {}
  for _, name in ipairs(missing) do
    local spec = TOOLS[name]
    if spec and spec.download and spec.download[OS] then
      table.insert(downloadables, name)
      print("  " .. #downloadables .. ". " .. spec.label .. " — " .. spec.desc)
    else
      print("  -  " .. spec.label .. " — " .. (spec.post_msg or "Install manual"))
    end
  end

  if #downloadables == 0 then
    print("")
    print("Semua tool yang missing harus diinstall manual.")
    return
  end

  print("")
  print("Pilih tool yang mau didownload (pisah koma, misal: 1,2,3):")
  vim.fn.inputsave()
  local raw = vim.fn.input(">> ")
  vim.fn.inputrestore()

  if raw == "" or raw == "0" then
    print("Download dibatalkan.")
    return
  end

  local picks = {}
  for s in raw:gmatch("%d+") do
    local n = tonumber(s)
    if n and n >= 1 and n <= #downloadables then
      picks[#picks+1] = downloadables[n]
    end
  end

  if #picks == 0 then
    print("Pilihan tidak valid. Download dibatalkan.")
    return
  end

  print("")
  print("Download: " .. table.concat(picks, ", "))
  vim.wait(500)

  -- sequential install via callback chain
  local idx = 1
  local function next_install()
    if idx > #picks then
      print("")
      print("🎉 Semua download selesai! Tool siap dipakai.")
      return
    end
    M.install_tool(picks[idx], function()
      idx = idx + 1
      next_install()
    end)
  end
  next_install()
end

return M
