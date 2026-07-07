-- anvim: help_check — auto-detect OS, cek path, download tool yg missing
-- user-friendly: cukup panggil :AnvimCheck, dia urus sisanya

local M = {}
M.results = {}
M.downloading = false

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
    download = nil, -- Java via package manager aja
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
    download = nil, -- git bundling is complex
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

  -- 1. exepath (PATH lookup, lintas OS)
  local exe = vim.fn.exepath(spec.check_paths[OS][1])
  if exe and exe ~= "" then
    return { found = true, path = exe, method = "PATH" }
  end

  -- 2. common paths
  for _, p in ipairs(spec.check_paths[OS]) do
    if not p:find("*") then
      local expanded = vim.fn.expand(p)
      if vim.fn.executable(expanded) == 1 then
        return { found = true, path = expanded, method = "common path" }
      end
    else
      -- wildcard — coba glob
      local matches = vim.fn.glob(p, false, true)
      if #matches > 0 then
        local expanded = vim.fn.expand(matches[1])
        if vim.fn.executable(expanded) == 1 then
          return { found = true, path = expanded, method = "wildcard" }
        end
      end
    end
  end

  -- 3. adb — cek ANDROID_HOME
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

-- ── download & install ────────────────────────────────────
function M.download_tool(name, cb)
  local spec = TOOLS[name]
  if not spec or not spec.download then
    vim.notify("[anvim] " .. name .. " tidak support auto-download.", vim.log.levels.WARN)
    if cb then cb(false) end
    return
  end

  local dl = spec.download[OS]
  if not dl then
    vim.notify("[anvim] Belum ada download untuk OS " .. OS, vim.log.levels.WARN)
    if cb then cb(false) end
    return
  end

  local homedir = vim.fn.expand("~")
  local dest = homedir .. "/.anvim/tools/" .. name
  vim.fn.mkdir(dest, "p")

  local zip_path = dest .. "/" .. dl.file
  vim.notify("[anvim] Download " .. spec.label .. " ...", vim.log.levels.INFO)

  M.downloading = true

  -- pake curl/wget
  local cmd
  if vim.fn.executable("curl") == 1 then
    cmd = { "curl", "-L", "-o", zip_path, dl.url }
  elseif vim.fn.executable("wget") == 1 then
    cmd = { "wget", "-O", zip_path, dl.url }
  else
    vim.notify("[anvim] Butuh curl atau wget untuk download.", vim.log.levels.ERROR)
    M.downloading = false
    if cb then cb(false) end
    return
  end

  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      M.downloading = false
      if code ~= 0 then
        vim.notify("[anvim] Gagal download " .. spec.label .. " (exit " .. code .. ")", vim.log.levels.ERROR)
        if cb then cb(false) end
        return
      end
      extract_tool(name, zip_path, dest, dl, cb)
    end,
  })
end

local function extract_tool(name, zip_path, dest, dl, cb)
  local extract_cmd
  local extract_dir = dest .. "/extracted"

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
    vim.notify("[anvim] " .. name .. " terdownload di " .. zip_path .. ". Ekstrak manual.", vim.log.levels.WARN)
    if cb then cb(false) end
    return
  end

  vim.fn.mkdir(extract_dir, "p")

  vim.fn.jobstart(extract_cmd, {
    on_exit = function(_, code)
      if code ~= 0 then
        vim.notify("[anvim] Gagal ekstrak " .. name, vim.log.levels.ERROR)
        if cb then cb(false) end
        return
      end

      -- cari binary di hasil ekstrak
      local bin_name = (OS == "windows") and (name .. ".exe") or name
      local found_path = vim.fn.glob(extract_dir .. "/**/" .. bin_name, false, true)
      local final_path

      if #found_path > 0 then
        final_path = vim.fn.fnamemodify(found_path[1], ":h")
      else
        final_path = extract_dir
      end

      -- pindahin ke dest biar rapi (pake shell biar glob * jalan)
      if OS == "windows" then
        vim.fn.system("move " .. extract_dir .. "\\* " .. dest .. "\\")
      else
        vim.fn.system("cp -r " .. extract_dir .. "/* " .. dest .. "/")
      end
      -- bersihin file sementara
      pcall(os.remove, zip_path)
      pcall(function()
        vim.fn.system("rm -rf " .. extract_dir)
      end)
      show_done_message(name, dest)
      if cb then cb(true) end
    end,
  })
end

local function show_done_message(name, dest)
  local spec = TOOLS[name]
  local msg = {
    "",
    "✓ " .. spec.label .. " berhasil didownload!",
    "  Lokasi: " .. dest,
    "",
    "  " .. (spec.post_msg or ""),
    "",
    "  Biar gampang, tambahkan ini ke ~/.bashrc atau ~/.zshrc:",
    '  export PATH="$PATH:' .. dest .. '"',
    "",
  }
  vim.notify(table.concat(msg, "\n"), vim.log.levels.INFO)
end

-- ── interactive check + download ─────────────────────────
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
      print("  [" .. #downloadables .. "] " .. spec.label .. " — " .. spec.desc)
    else
      print("  -  " .. spec.label .. " — " .. (spec.post_msg or "Install manual"))
    end
  end

  if #downloadables == 0 then
    print("")
    print("Semua tool yang missing harus diinstall manual.")
    print("Cek link di atas ya.")
    return
  end

  print("")
  print("Ketik angka tool yang mau didownload (pisah koma, misal 1,2)")
  print("Atau tekan Enter untuk skip download.")
  vim.fn.inputsave()
  local answer = vim.fn.input(">> ")
  vim.fn.inputrestore()

  if answer == "" then return end

  local selected = {}
  for num in answer:gmatch("%d+") do
    local idx = tonumber(num)
    if idx and idx >= 1 and idx <= #downloadables then
      table.insert(selected, downloadables[idx])
    end
  end

  if #selected == 0 then return end

  print("")
  print("Download " .. table.concat(selected, ", ") .. "? (y/n) ")
  vim.fn.inputsave()
  local confirm = vim.fn.input(">> ")
  vim.fn.inputrestore()

  if confirm:lower() ~= "y" then
    print("Download dibatalkan.")
    return
  end

  -- download berurutan
  local function download_next(idx)
    if idx > #selected then
      print("")
      print("Selesai! Jangan lupa restart terminal atau source ulang rc file.")
      return
    end
    M.download_tool(selected[idx], function()
      download_next(idx + 1)
    end)
  end
  download_next(1)
end

-- ── setup anvim check di init ──────────────────────────────
function M.setup_check()
  -- auto-run pas dashboard pertama x dibuka, nanti di dashboard.lua
end

return M
