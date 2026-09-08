-- anvim: system_check — detect OS, cek tools + versi minimum, UI selectable
-- human-readable: "Check System Tools". Single source untuk health (shim).

local M = {}
M.results = {}
local alert = require("anvim.status-alert")
local util = require("anvim.util")

-- namespace khusus: dibersihkan tiap render (lihat dashboard.lua)
local NS = vim.api.nvim_create_namespace("anvim_check")

local OS = util.OS
local ARCH = util.ARCH
local WIN_BIN = util.local_bin() -- dipakai check_paths windows

-- Versi minimum yang didukung (selaras Flutter 3.47 / AGP 9.x era).
M.MIN_VERSIONS = {
  adb = { 1, 0, 39 },
  java = { 17 },
  flutter = { 3 },
  git = { 2 },
  gradle = { 8 },
  scrcpy = { 2 },
  node = { 18 },
}

local FLUTTER_VER = "3.47.0"
local GRADLE_VER = "9.7.1"
local SCRCPY_VER = "4.1"
local SCRCPY_BASE = "https://github.com/Genymobile/scrcpy/releases/download/v" .. SCRCPY_VER

local function flutter_macos_file()
  if ARCH == "arm64" then
    return "flutter_macos_arm64_" .. FLUTTER_VER .. "-stable.zip"
  end
  return "flutter_macos_" .. FLUTTER_VER .. "-stable.zip"
end

--- Download spec scrcpy per-OS (tetap di tools-dir: no_deploy).
--- Linux ARM64 tanpa aset resmi → nil (fallback post_msg di TOOLS).
local function scrcpy_download()
  local sums = SCRCPY_BASE .. "/SHA256SUMS.txt"
  if OS == "linux" then
    if ARCH ~= "x86_64" then return nil end
    local f = "scrcpy-linux-x86_64-v" .. SCRCPY_VER .. ".tar.gz"
    return {
      linux = { url = SCRCPY_BASE .. "/" .. f, file = "scrcpy.tar.gz", dir = "scrcpy-linux-x86_64-v" .. SCRCPY_VER, sha256_url = sums, sha256_file = f, no_deploy = true },
    }
  elseif OS == "macos" then
    local f = ARCH == "arm64" and ("scrcpy-macos-aarch64-v" .. SCRCPY_VER .. ".tar.gz") or ("scrcpy-macos-x86_64-v" .. SCRCPY_VER .. ".tar.gz")
    return {
      macos = { url = SCRCPY_BASE .. "/" .. f, file = "scrcpy.tar.gz", dir = "scrcpy", sha256_url = sums, sha256_file = f, no_deploy = true },
    }
  else
    local f = "scrcpy-win64-v" .. SCRCPY_VER .. ".zip"
    return {
      windows = { url = SCRCPY_BASE .. "/" .. f, file = "scrcpy.zip", dir = "scrcpy-win64-v" .. SCRCPY_VER, sha256_url = sums, sha256_file = f, no_deploy = true },
    }
  end
end

-- ── tool definitions ──
local TOOLS = {
  adb = {
    label = "ADB", desc = "Android Debug Bridge — device communication",
    bin = (OS == "windows") and "adb.exe" or "adb",
    hint = "Install Android SDK Platform-Tools or use :AnvimCheck auto-download.",
    url = "https://developer.android.com/studio/command-line",
    ver_arg = "version",
    check_paths = {
      linux   = { "adb", "~/.local/bin/adb", "~/Android/Sdk/platform-tools/adb", "~/android/platform-tools/adb", "/usr/bin/adb", "/usr/local/bin/adb" },
      macos   = { "adb", "~/.local/bin/adb", "~/Android/Sdk/platform-tools/adb", "~/Library/Android/sdk/platform-tools/adb", "/usr/local/bin/adb" },
      windows = { "adb.exe", WIN_BIN .. "\\adb.exe", "~/AppData/Local/Android/Sdk/platform-tools/adb.exe", "C:\\Android\\platform-tools\\adb.exe" },
    },
    download = {
      linux   = { url = "https://dl.google.com/android/repository/platform-tools-latest-linux.zip", file = "platform-tools-latest-linux.zip", dir = "platform-tools", sha256_url = nil },
      macos   = { url = "https://dl.google.com/android/repository/platform-tools-latest-darwin.zip", file = "platform-tools-latest-darwin.zip", dir = "platform-tools", sha256_url = nil },
      windows = { url = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip", file = "platform-tools-latest-windows.zip", dir = "platform-tools", sha256_url = nil },
    },
  },
  java = {
    label = "Java", desc = "Java Runtime — Gradle build Android (min 17)",
    bin = (OS == "windows") and "java.exe" or "java",
    hint = "Install OpenJDK 17+.",
    url = "https://adoptium.net",
    ver_arg = "--version",
    check_paths = {
      linux   = { "java", "~/.local/bin/java", "/usr/bin/java", "/usr/lib/jvm/*/bin/java" },
      macos   = { "java", "~/.local/bin/java", "/usr/bin/java", "/Library/Java/JavaVirtualMachines/*/Contents/Home/bin/java" },
      windows = { "java.exe", "C:\\Program Files\\Java\\*\\bin\\java.exe", "C:\\Program Files (x86)\\Java\\*\\bin\\java.exe" },
    },
    download = nil,
    post_msg = "Download Temurin JDK 17+: https://adoptium.net",
  },
  flutter = {
    label = "Flutter", desc = "Flutter SDK — multiplatform UI",
    bin = (OS == "windows") and "flutter.bat" or "flutter",
    hint = "Install the Flutter SDK and set PATH.",
    url = "https://flutter.dev/docs/get-started/install",
    ver_arg = "--version",
    check_paths = {
      linux   = { "flutter", "~/.local/bin/flutter", "~/flutter/bin/flutter", "/usr/local/flutter/bin/flutter", "/opt/flutter/bin/flutter" },
      macos   = { "flutter", "~/.local/bin/flutter", "~/flutter/bin/flutter", "/usr/local/flutter/bin/flutter", "/opt/homebrew/bin/flutter" },
      windows = { "flutter.bat", WIN_BIN .. "\\flutter.bat", "~/flutter/bin/flutter.bat", "C:\\flutter\\bin\\flutter.bat" },
    },
    download = {
      linux   = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_" .. FLUTTER_VER .. "-stable.tar.xz", file = "flutter.tar.xz", dir = "flutter", sha256_url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_" .. FLUTTER_VER .. "-stable.tar.xz.sha256" },
      macos   = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/" .. flutter_macos_file(), file = "flutter.zip", dir = "flutter", sha256_url = nil },
      windows = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_" .. FLUTTER_VER .. "-stable.zip", file = "flutter.zip", dir = "flutter", sha256_url = nil },
    },
  },
  git = {
    label = "Git", desc = "Version control — branch & project info",
    bin = (OS == "windows") and "git.exe" or "git",
    hint = "Install Git from your package manager.",
    url = "https://git-scm.com/downloads",
    ver_arg = "--version",
    check_paths = {
      linux   = { "git", "~/.local/bin/git", "/usr/bin/git", "/usr/local/bin/git" },
      macos   = { "git", "~/.local/bin/git", "/usr/bin/git", "/usr/local/bin/git" },
      windows = { "git.exe", "C:\\Program Files\\Git\\bin\\git.exe" },
    },
    download = nil,
    post_msg = "Install Git: https://git-scm.com/download/" .. OS,
  },
  gradle = {
    label = "Gradle", desc = "Build tool Android (min 8)",
    bin = (OS == "windows") and "gradle.bat" or "gradle",
    hint = "Install Gradle or use the project gradlew.",
    url = "https://gradle.org/install",
    ver_arg = "--version",
    check_paths = {
      linux   = { "gradle", "~/.local/bin/gradle", "/usr/bin/gradle", "/usr/local/bin/gradle" },
      macos   = { "gradle", "~/.local/bin/gradle", "/usr/bin/gradle", "/usr/local/bin/gradle" },
      windows = { "gradle.bat", WIN_BIN .. "\\gradle.bat", "C:\\Gradle\\bin\\gradle.bat" },
    },
    download = {
      linux   = { url = "https://services.gradle.org/distributions/gradle-" .. GRADLE_VER .. "-bin.zip", file = "gradle.zip", dir = "gradle-" .. GRADLE_VER, sha256_url = "https://services.gradle.org/distributions/gradle-" .. GRADLE_VER .. "-bin.zip.sha256" },
      macos   = { url = "https://services.gradle.org/distributions/gradle-" .. GRADLE_VER .. "-bin.zip", file = "gradle.zip", dir = "gradle-" .. GRADLE_VER, sha256_url = "https://services.gradle.org/distributions/gradle-" .. GRADLE_VER .. "-bin.zip.sha256" },
      windows = { url = "https://services.gradle.org/distributions/gradle-" .. GRADLE_VER .. "-bin.zip", file = "gradle.zip", dir = "gradle-" .. GRADLE_VER, sha256_url = "https://services.gradle.org/distributions/gradle-" .. GRADLE_VER .. "-bin.zip.sha256" },
    },
  },
  emulator = {
    label = "Emulator", desc = "Android Emulator binary (optional, for AVDs)",
    bin = (OS == "windows") and "emulator.exe" or "emulator",
    hint = "Install via Android Studio SDK Manager → SDK Tools → Android Emulator.",
    url = "https://developer.android.com/studio#command-line-tools-only",
    ver_arg = "--version",
    optional = true,
    check_paths = {
      linux   = { "emulator", "~/.local/bin/emulator", "~/Android/Sdk/emulator/emulator", "~/android/emulator/emulator", "/usr/bin/emulator", "/usr/local/bin/emulator" },
      macos   = { "emulator", "~/.local/bin/emulator", "~/Library/Android/sdk/emulator/emulator", "~/Android/Sdk/emulator/emulator", "/usr/local/bin/emulator" },
      windows = { "emulator.exe", WIN_BIN .. "\\emulator.exe", "~/AppData/Local/Android/Sdk/emulator/emulator.exe" },
    },
    download = nil,
    post_msg = "Install Android SDK Emulator via Android Studio SDK Manager.",
  },
  scrcpy = {
    label = "Scrcpy", desc = "Show + control phone (replaces emulator)",
    bin = (OS == "windows") and "scrcpy.exe" or "scrcpy",
    hint = "Install scrcpy via :AnvimCheck or a distro package.",
    url = "https://github.com/Genymobile/scrcpy",
    ver_arg = "--version",
    optional = true,
    check_paths = {
      linux   = { "scrcpy", "~/.local/bin/scrcpy", "~/.anvim/tools/scrcpy/**/scrcpy" },
      macos   = { "scrcpy", "~/.local/bin/scrcpy", "~/.anvim/tools/scrcpy/**/scrcpy" },
      windows = { "scrcpy.exe", WIN_BIN .. "\\scrcpy.exe", "~/.anvim/tools/scrcpy/**/scrcpy.exe" },
    },
    download = scrcpy_download(),
    post_msg = "Install scrcpy: distro package (apt/brew/choco) or :AnvimCheck (x86_64).",
  },
  node = {
    label = "Node", desc = "Node.js — npm scripts (dev/build/test)",
    bin = (OS == "windows") and "node.exe" or "node",
    hint = "Install Node.js LTS for npm projects.",
    url = "https://nodejs.org",
    ver_arg = "--version",
    optional = true,
    check_paths = {
      linux   = { "node", "~/.local/bin/node", "/usr/bin/node", "/usr/local/bin/node" },
      macos   = { "node", "~/.local/bin/node", "/usr/bin/node", "/usr/local/bin/node", "/opt/homebrew/bin/node" },
      windows = { "node.exe", WIN_BIN .. "\\node.exe", "C:\\Program Files\\nodejs\\node.exe" },
    },
    download = nil,
    post_msg = "Install Node.js LTS: https://nodejs.org",
  },
}

function M.get_tools_spec()
  return TOOLS
end

function M.reset_cache()
  M._adb_cache = nil
end

--- Hasil cek terakhir (tanpa spawn). Dipakai dashboard agar buka instan;
--- scan sungguhan hanya saat user trigger (:AnvimCheck / c).
function M.last_results()
  if type(M.results) == "table" then return M.results end
  return {}
end

--- Tool yang relevan per tipe project (git selalu ikut sebagai info).
--- Dashboard + auto-warn pakai ini agar tidak menagih tool tak relevan
--- (mis. flutter untuk project node).
function M.required_tools(proj_type)
  local map = {
    flutter = { "adb", "flutter" },
    android = { "adb", "java", "gradle" },
    node = { "node" },
  }
  local list = {}
  for _, n in ipairs(map[proj_type] or { "adb", "java", "flutter", "git", "gradle" }) do
    table.insert(list, n)
  end
  local has_git = false
  for _, n in ipairs(list) do if n == "git" then has_git = true break end end
  if not has_git then table.insert(list, "git") end
  return list
end

function M.get_os()
  return OS, ARCH
end

-- ── cari binary (prioritas: bin_dir kanonis → PATH → check_paths →
--    ANDROID_HOME → folder custom user). Yang ketemu duluan yang ditampilkan.
local function bin_candidates(spec)
  local names = { spec.bin }
  if OS == "windows" then
    if spec.bin:sub(-4) == ".exe" then
      table.insert(names, spec.bin:sub(1, -5) .. ".bat")
    elseif spec.bin:sub(-4) == ".bat" then
      table.insert(names, spec.bin:sub(1, -5) .. ".exe")
    else
      table.insert(names, spec.bin .. ".exe")
      table.insert(names, spec.bin .. ".bat")
    end
  end
  return names
end

local function find_tool(name, deep)
  local spec = TOOLS[name]
  if not spec then return nil end
  local names = bin_candidates(spec)

  -- 1. kanonis: install.bin_dir (default ~/.local/bin)
  local cfg_ok, cfg = pcall(function() return require("anvim.config").get() end)
  local bin_dir = (cfg_ok and cfg and cfg.install and cfg.install.bin_dir) or util.local_bin()
  local sep = OS == "windows" and "\\" or "/"
  for _, b in ipairs(names) do
    local p = bin_dir .. sep .. b
    if vim.fn.executable(p) == 1 then
      return { found = true, path = p }
    end
  end

  -- 2. PATH sistem
  local exe = vim.fn.exepath(spec.check_paths[OS][1])
  if exe and exe ~= "" then
    return { found = true, path = exe }
  end

  -- 3. lokasi umum
  for _, p in ipairs(spec.check_paths[OS]) do
    if not p:find("*", 1, true) then
      local e = vim.fn.expand(p)
      if vim.fn.executable(e) == 1 then
        return { found = true, path = e }
      end
    else
      local matches = vim.fn.glob(p, false, true)
      if #matches > 0 then
        local e = vim.fn.expand(matches[1])
        if vim.fn.executable(e) == 1 then
          return { found = true, path = e }
        end
      end
    end
  end

  if name == "adb" or name == "emulator" then
    local ah = vim.env.ANDROID_HOME or vim.env.ANDROID_SDK_ROOT
    if ah then
      local sub = name == "adb" and "platform-tools/adb" or "emulator/emulator"
      for _, p in ipairs({ ah .. "/" .. sub, ah .. "\\" .. sub:gsub("/", "\\") .. ".exe" }) do
        if vim.fn.executable(vim.fn.expand(p)) == 1 then
          return { found = true, path = vim.fn.expand(p) }
        end
      end
    end
  end

  -- 5. folder custom user (Downloads/Documents/dll) — fallback terakhir,
  --    hanya saat deep (interaktif/slow) agar dashboard cepat
  if deep ~= false then
    for _, b in ipairs(names) do
      local hit = util.search_extra_dirs(b, names)
      if hit then
        return { found = true, path = hit }
      end
    end
  end

  return { found = false, path = nil }
end

--- Path absolut adb (SDK/ANDROID_HOME/local/bin/PATH/folder custom).
--- Jangan pakai "adb" mentah: PATH Neovim (GUI/launcher) sering beda
--- dengan terminal. Cache per session; reset tiap check_all.
M._adb_cache = nil

function M.adb_bin()
  if M._adb_cache ~= nil then
    return M._adb_cache or nil
  end
  local r = find_tool("adb")
  local path = (r and r.path and r.path ~= "") and r.path or nil
  M._adb_cache = path or false
  return path
end

-- ── parse versi: "openjdk 17.0.9" / "Gradle 9.7.1" / "Bridge version 1.0.41"
--    / "Flutter 3.47.0" / "git version 2.43.0" → {17,0,9}
function M._parse_version(name, text)
  if not text or text == "" then return nil end
  local pat
  if name == "java" then
    pat = '"?%d+%.%d+%.?%d*'
  elseif name == "gradle" then
    pat = 'Gradle%s+%d+%.%d+%.?%d*'
  elseif name == "adb" or name == "emulator" then
    pat = 'version%s+%d+%.%d+%.?%d*'
  elseif name == "flutter" then
    pat = 'Flutter%s+%d+%.%d+%.?%d*'
  elseif name == "git" then
    pat = 'git%s+version%s+%d+%.%d+%.?%d*'
  else
    pat = '%d+%.%d+%.?%d*'
  end
  local s = text:match(pat)
  if not s then
    local single = text:match("(%d+)")
    if single then return { tonumber(single) } end
    return nil
  end
  local parts = {}
  for n in s:gmatch("%d+") do table.insert(parts, tonumber(n)) end
  if #parts == 0 then
    local single = text:match("(%d+)")
    if single then return { tonumber(single) } end
    return nil
  end
  return parts
end

function M._ver_to_string(ver)
  if not ver or #ver == 0 then return "" end
  return table.concat(ver, ".")
end

--- Bandingkan dengan minimum. Return true jika memenuhi / tidak ada minimum.
function M._meets_min(name, ver)
  local min = M.MIN_VERSIONS[name]
  if not min or not ver or #ver == 0 then return true end
  for i = 1, math.max(#min, #ver) do
    local a = ver[i] or 0
    local b = min[i] or 0
    if a > b then return true end
    if a < b then return false end
  end
  return true
end

local function tool_version_output(bin, ver_arg)
  local ok, out = pcall(vim.fn.system, util.esc(bin) .. " " .. (ver_arg or "--version") .. " 2>&1 | head -3")
  if ok and out and vim.trim(out) ~= "" then
    return vim.trim(out):gsub("\n.*$", ""):sub(1, 100)
  end
  return ""
end

-- ── public check (opts.deep=false = skip folder custom, untuk fase cepat) ──
function M.check_tool(name, opts)
  local spec = TOOLS[name]
  if not spec then return { found = false, label = name, status = "missing" } end
  local deep = not opts or opts.deep ~= false
  local r = find_tool(name, deep)
  r.label = spec.label
  r.desc = spec.desc
  r.hint = spec.hint
  r.url = spec.url
  r.can_download = spec.download ~= nil
  r.optional = spec.optional or false
  r.name = name
  r.bin = spec.bin
  r.download = spec.download and spec.download[OS] or nil
  r.post_msg = spec.post_msg
  if r.found then
    local exe = (r.path and r.path ~= "") and r.path or spec.bin
    r.version_text = tool_version_output(exe, spec.ver_arg)
    r.version = M._parse_version(name, r.version_text)
    r.meets_min = M._meets_min(name, r.version)
    r.status = r.meets_min and "ok" or "old"
  else
    r.status = "missing"
  end
  M.results[name] = r
  return r
end

function M.check_all(only, opts)
  M.results = {}
  M.reset_cache()
  if not only then
    local ok, c = pcall(function() return require("anvim.config").get() end)
    if ok and c and c.health_check and c.health_check.tools then
      only = c.health_check.tools
    else
      only = { "adb", "java", "flutter", "git", "gradle", "scrcpy" }
    end
  end
  for _, name in ipairs(only) do
    M.check_tool(name, opts)
  end
  return M.results
end

--- Tool wajib yang hilang (abaikan optional seperti emulator).
function M.get_missing()
  local missing = {}
  for _, name in ipairs(util.TOOL_ORDER) do
    local r = M.results[name]
    if r and not r.found and not r.optional then table.insert(missing, name) end
  end
  for name, r in pairs(M.results) do
    local known = false
    for _, x in ipairs(util.TOOL_ORDER) do if x == name then known = true break end end
    if not known and not r.found and not r.optional then table.insert(missing, name) end
  end
  return missing
end

--- Tool yang versinya di bawah minimum.
function M.get_outdated()
  local out = {}
  for name, r in pairs(M.results) do
    if r.found and r.status == "old" then table.insert(out, name) end
  end
  table.sort(out)
  return out
end

function M.format_line(name, r)
  local spec = TOOLS[name]
  local label = (r and r.label) or (spec and spec.label) or name
  if r and r.found then
    local vstr = ""
    if type(r.version) == "table" and #r.version > 0 then
      vstr = " " .. M._ver_to_string(r.version)
    elseif type(r.version) == "string" and r.version ~= "" then
      vstr = " " .. r.version
    end
    if r.status == "old" then
      local min = M.MIN_VERSIONS[name] and table.concat(M.MIN_VERSIONS[name], ".") or "?"
      return string.format("⚠ %s%s outdated (min %s) — %s", label, vstr, min, r.path)
    end
    return string.format("✓ %s%s — %s", label, vstr, r.path)
  end
  local hint = (r and r.hint) or (spec and spec.hint) or ""
  if hint ~= "" then
    return string.format("✗ %s not found — %s", label, hint)
  end
  return string.format("✗ %s not found", label)
end

--- Masalah environment (di luar binary): ANDROID_HOME, emulator, gradlew bit.
function M.get_env_issues()
  local issues = {}
  local ah = vim.env.ANDROID_HOME or vim.env.ANDROID_SDK_ROOT
  if not ah or ah == "" then
    table.insert(issues, {
      label = "ANDROID_HOME is not set",
      hint = 'export ANDROID_HOME="$HOME/Android/Sdk" >> ~/.bashrc (adjust to your shell)',
    })
  elseif vim.fn.isdirectory(vim.fn.expand(ah)) ~= 1 then
    table.insert(issues, {
      label = "ANDROID_HOME points to a missing folder: " .. ah,
      hint = "Fix the SDK path in your shell RC.",
    })
  end
  local emu = M.results.emulator or M.check_tool("emulator")
  if emu and not emu.found then
    table.insert(issues, {
      label = "Emulator binary missing (cannot list AVDs)",
      hint = "Android Studio → SDK Manager → SDK Tools → Android Emulator.",
    })
  end
  -- adb ketemu di terminal tapi tidak di Neovim = PATH beda (GUI/launcher)
  local adb_path = M.adb_bin()
  if not adb_path and vim.fn.executable("adb") == 0 then
    table.insert(issues, {
      label = "adb not visible to Neovim (works in terminal?)",
      hint = "Launch nvim from terminal, or run :AnvimCheck to install adb.",
    })
  end
  return issues
end

--- Doctor: tampilkan env issues + saran fix. Ringan, read-only.
function M.doctor()
  local lines = { "OS: " .. OS:upper() .. "  Arch: " .. ARCH }
  local ah = vim.env.ANDROID_HOME or vim.env.ANDROID_SDK_ROOT or "(unset)"
  table.insert(lines, "ANDROID_HOME: " .. ah)
  table.insert(lines, "adb (nvim): " .. (M.adb_bin() or "NOT FOUND"))
  table.insert(lines, "")
  local issues = M.get_env_issues()
  if #issues == 0 then
    table.insert(lines, "Environment OK — no issues.")
  else
    for _, is in ipairs(issues) do
      table.insert(lines, "• " .. is.label)
      table.insert(lines, "  → " .. is.hint)
    end
  end
  local buf = vim.api.nvim_create_buf(false, true)
  local width, height, col, row = util.float_geom(0.6, 0.5, 60, 12)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = math.min(76, width), height = math.min(#lines + 4, height),
    col = col, row = row, style = "minimal", border = "rounded",
    title = " anvim Doctor ", title_pos = "center",
  })
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.keymap.set("n", "q", function() util.close_win_buf(win, buf) end, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", function() util.close_win_buf(win, buf) end, { buffer = buf, nowait = true, silent = true })
end

--- Rapikan install lama: buang entri ~/.anvim/tools dari PATH session,
--- pastikan bin_dir di depan, buatkan symlink yang hilang untuk tool yang
--- sudah ada di tools-dir (tanpa download ulang). Return daftar perbaikan.
function M.repair()
  local fixed = {}
  local cfg_ok, cfg = pcall(function() return require("anvim.config").get() end)
  local bin_dir = (cfg_ok and cfg and cfg.install and cfg.install.bin_dir) or util.local_bin()
  local tools_base = (cfg_ok and cfg and cfg.install and cfg.install.dir) or util.tools_dir()
  local sep = OS == "windows" and ";" or ":"

  -- 1. bersihkan PATH session dari entri tools-dir (sumber detect salah)
  if OS ~= "windows" then
    local kept, dropped = {}, 0
    for p in (vim.env.PATH or ""):gmatch("[^:]+") do
      if p:find(tools_base, 1, true) then
        dropped = dropped + 1
      else
        table.insert(kept, p)
      end
    end
    if dropped > 0 then
      vim.env.PATH = table.concat(kept, ":")
      table.insert(fixed, "PATH dibersihkan (" .. dropped .. " entri tools-dir dibuang)")
    end
    if not vim.env.PATH:find(bin_dir, 1, true) then
      vim.env.PATH = bin_dir .. ":" .. vim.env.PATH
      table.insert(fixed, "PATH ditambah " .. bin_dir)
    end
  end

  -- 2. symlink hilang untuk tool yang file-nya ada di tools-dir
  if OS ~= "windows" then
    pcall(vim.fn.mkdir, bin_dir, "p")
    for _, name in ipairs({ "adb", "flutter", "gradle" }) do
      local spec = TOOLS[name]
      if spec then
        for _, b in ipairs(bin_candidates(spec)) do
          local link = bin_dir .. "/" .. b
          if vim.fn.executable(link) ~= 1 then
            local cands = vim.fn.glob(tools_base .. "/" .. name .. "/**/" .. b, false, true)
            for _, src in ipairs(cands) do
              if vim.fn.executable(src) == 1 then
                pcall(vim.fn.system, "ln -sfn " .. util.esc(src) .. " " .. util.esc(link) .. " 2>&1")
                if vim.fn.executable(link) == 1 then
                  table.insert(fixed, b .. " → symlink dari tools-dir")
                end
                break
              end
            end
          end
          if vim.fn.executable(link) == 1 then break end
        end
      end
    end
  end
  return fixed
end

-- ── UI state ──
M._ui = { buf = nil, win = nil, items = {}, selected = 1 }

local function ui_close()
  util.close_win_buf(M._ui.win, M._ui.buf)
  M._ui.buf, M._ui.win, M._ui.items, M._ui.selected = nil, nil, {}, 1
end

local function ui_rebuild()
  M.check_all()
  -- project node → cek node juga (user-triggered, deep OK)
  pcall(function()
    if require("anvim.project").detect().type == "node" and not M.results.node then
      M.check_tool("node")
    end
  end)
  local items = {}
  for _, name in ipairs(util.sorted_tool_names(M.results)) do
    local r = M.results[name]
    local kind = "info"
    if not r.found and r.can_download then kind = "installable"
    elseif not r.found then kind = "manual" end
    table.insert(items, { name = name, result = r, kind = kind })
  end
  M._ui.items = items
  M._ui.env = M.get_env_issues()
  if M._ui.selected < 1 or M._ui.selected > #items then M._ui.selected = 1 end
end

local function ui_render()
  local buf = M._ui.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local width = 62
  local lines = {
    "OS: " .. OS:upper() .. "  Arch: " .. ARCH,
    string.rep("─", width - 2),
  }
  for i, it in ipairs(M._ui.items) do
    local sel = (i == M._ui.selected) and "→ " or "  "
    local line = sel .. M.format_line(it.name, it.result)
    if #line > width then line = line:sub(1, width - 3) .. "..." end
    table.insert(lines, line)
  end
  table.insert(lines, string.rep("─", width - 2))
  for _, is in ipairs(M._ui.env or {}) do
    table.insert(lines, "! " .. is.label)
  end
  table.insert(lines, "Enter Install/Open  i Install all  q Quit")
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  pcall(require, "anvim.theme")
  -- TANPA highlight baris (cursor only), sama seperti dashboard.
  pcall(vim.api.nvim_buf_clear_namespace, buf, NS, 0, -1)
end

local function ui_install_queue(names, on_all_done)
  local ins_ok, ins = pcall(require, "anvim.installation")
  if not ins_ok then
    alert.error("install", "installation module failed to load")
    if on_all_done then on_all_done(false) end
    return
  end
  -- tutup UI selama install (progress window yang tampil);
  -- UI dibuka lagi sekali saat queue selesai/gagal/cancel.
  ui_close()
  ins.install_cancelled = false
  local idx = 1
  local function next()
    if ins.install_cancelled then
      ins.install_cancelled = false
      vim.schedule(function()
        M.interactive()
        if on_all_done then on_all_done(false) end
      end)
      return
    end
    if idx > #names then
      alert.ok("All downloads complete! Tools ready.")
      vim.schedule(function()
        M.interactive()
        if on_all_done then on_all_done(true) end
      end)
      return
    end
    local tool = names[idx]
    local spec = TOOLS[tool]
    local dl = spec and spec.download and spec.download[OS]
    if not dl then
      idx = idx + 1
      vim.schedule(next)
      return
    end
    ins.install_tool(tool, dl, spec.label, spec.bin, function(ok_done)
      idx = idx + 1
      if not ok_done then
        alert.error("install", tool .. " failed — chain stopped")
        vim.schedule(function()
          M.interactive()
          if on_all_done then on_all_done(false) end
        end)
        return
      end
      vim.schedule(next)
    end)
  end
  next()
end

function M._ui_nav(dir)
  local n = #M._ui.items
  if n == 0 then return end
  local sel = (M._ui.selected or 1) + dir
  if sel < 1 then sel = n end
  if sel > n then sel = 1 end
  M._ui.selected = sel
  ui_render()
end

function M._ui_choose()
  local it = M._ui.items[M._ui.selected]
  if not it then return end
  if it.kind == "installable" then
    ui_install_queue({ it.name })
  elseif it.kind == "manual" then
    local r = it.result
    alert.warn((r.label or it.name) .. " needs manual install.\n" .. (r.post_msg or r.hint or ""))
  else
    local r = it.result
    alert.info(M.format_line(it.name, r))
  end
end

function M._ui_install_all()
  local names = {}
  for _, it in ipairs(M._ui.items) do
    if it.kind == "installable" then table.insert(names, it.name) end
  end
  if #names == 0 then
    alert.info("No tools available for auto-download.")
    return
  end
  ui_install_queue(names)
end

function M._ui_close()
  ui_close()
  vim.schedule(function() pcall(require("anvim.dashboard").open) end)
end

-- ── interactive check: floating selectable UI (keyboard-driven) ──
function M.interactive()
  local repaired = M.repair()
  ui_rebuild()

  local missing = M.get_missing()
  local outdated = M.get_outdated()
  -- optional yang belum install tapi bisa di-download (mis. scrcpy)
  -- tetap tampilkan UI agar bisa di-install, bukan "ALL GOOD" buta
  local installable = 0
  for _, it in ipairs(M._ui.items) do
    if it.kind == "installable" then installable = installable + 1 end
  end
  if #missing == 0 and #outdated == 0 and installable == 0 then
    if #repaired > 0 then
      alert.ok("All tools detected (" .. table.concat(repaired, "; ") .. ")")
    else
      alert.ok("All tools detected")
    end
    vim.schedule(function() pcall(require("anvim.dashboard").open) end)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local width, height, col, row = util.float_geom(0.6, 0.6, 62, 14)
  width = math.min(66, width)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = width, height = math.min(#M._ui.items + 6, height),
    col = col, row = row,
    style = "minimal", border = "rounded",
    title = " System Check ", title_pos = "center",
  })
  vim.wo[win].winblend = 10
  pcall(vim.api.nvim_buf_set_name, buf, "anvim://system-check")
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "anvim-check"

  M._ui.buf, M._ui.win = buf, win
  ui_render()

  local map = function(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
  end
  map("j", function() M._ui_nav(1) end, "Next")
  map("k", function() M._ui_nav(-1) end, "Prev")
  map("<Down>", function() M._ui_nav(1) end, "Next")
  map("<Up>", function() M._ui_nav(-1) end, "Prev")
  map("<CR>", function() M._ui_choose() end, "Install/show")
  map("i", function() M._ui_install_all() end, "Install all")
  map("q", function() M._ui_close() end, "Quit")
  map("<Esc>", function() M._ui_close() end, "Quit")
end

return M
