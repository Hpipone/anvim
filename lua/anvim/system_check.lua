-- anvim: system_check — detect OS, cek tools + versi minimum, UI selectable
-- human-readable: "Check System Tools". Single source untuk health (shim).

local M = {}
M.results = {}
local alert = require("anvim.status-alert")
local util = require("anvim.util")

local OS = util.OS
local ARCH = util.ARCH

-- Versi minimum yang didukung (selaras Flutter 3.47 / AGP 9.x era).
M.MIN_VERSIONS = {
  adb = { 1, 0, 39 },
  java = { 17 },
  flutter = { 3 },
  git = { 2 },
  gradle = { 8 },
}

local FLUTTER_VER = "3.47.0"
local GRADLE_VER = "9.7.1"

local function flutter_macos_file()
  if ARCH == "arm64" then
    return "flutter_macos_arm64_" .. FLUTTER_VER .. "-stable.zip"
  end
  return "flutter_macos_" .. FLUTTER_VER .. "-stable.zip"
end

-- ── tool definitions ──
local TOOLS = {
  adb = {
    label = "ADB", desc = "Android Debug Bridge — komunikasi device",
    bin = (OS == "windows") and "adb.exe" or "adb",
    hint = "Install Android SDK Platform-Tools atau pakai :AnvimCheck auto-download.",
    url = "https://developer.android.com/studio/command-line",
    ver_arg = "version",
    check_paths = {
      linux   = { "adb", "~/Android/Sdk/platform-tools/adb", "~/android/platform-tools/adb", "~/.local/bin/adb", "/usr/bin/adb", "/usr/local/bin/adb" },
      macos   = { "adb", "~/Android/Sdk/platform-tools/adb", "~/Library/Android/sdk/platform-tools/adb", "~/.local/bin/adb", "/usr/local/bin/adb" },
      windows = { "adb.exe", "~/AppData/Local/Android/Sdk/platform-tools/adb.exe", "C:\\Android\\platform-tools\\adb.exe" },
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
      linux   = { "java", "/usr/bin/java", "/usr/lib/jvm/*/bin/java" },
      macos   = { "java", "/usr/bin/java", "/Library/Java/JavaVirtualMachines/*/Contents/Home/bin/java" },
      windows = { "java.exe", "C:\\Program Files\\Java\\*\\bin\\java.exe", "C:\\Program Files (x86)\\Java\\*\\bin\\java.exe" },
    },
    download = nil,
    post_msg = "Download Temurin JDK 17+: https://adoptium.net",
  },
  flutter = {
    label = "Flutter", desc = "Flutter SDK — UI multiplatform",
    bin = (OS == "windows") and "flutter.exe" or "flutter",
    hint = "Install Flutter SDK dan set PATH.",
    url = "https://flutter.dev/docs/get-started/install",
    ver_arg = "--version",
    check_paths = {
      linux   = { "flutter", "~/flutter/bin/flutter", "/usr/local/flutter/bin/flutter", "/opt/flutter/bin/flutter", "~/.local/bin/flutter" },
      macos   = { "flutter", "~/flutter/bin/flutter", "/usr/local/flutter/bin/flutter", "/opt/homebrew/bin/flutter", "~/.local/bin/flutter" },
      windows = { "flutter.exe", "~/flutter/bin/flutter.exe", "C:\\flutter\\bin\\flutter.exe" },
    },
    download = {
      linux   = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_" .. FLUTTER_VER .. "-stable.tar.xz", file = "flutter.tar.xz", dir = "flutter", sha256_url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_" .. FLUTTER_VER .. "-stable.tar.xz.sha256" },
      macos   = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/" .. flutter_macos_file(), file = "flutter.zip", dir = "flutter", sha256_url = nil },
      windows = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_" .. FLUTTER_VER .. "-stable.zip", file = "flutter.zip", dir = "flutter", sha256_url = nil },
    },
  },
  git = {
    label = "Git", desc = "Version control — info branch & project version",
    bin = (OS == "windows") and "git.exe" or "git",
    hint = "Install Git dari package manager.",
    url = "https://git-scm.com/downloads",
    ver_arg = "--version",
    check_paths = {
      linux   = { "git", "/usr/bin/git", "/usr/local/bin/git" },
      macos   = { "git", "/usr/bin/git", "/usr/local/bin/git" },
      windows = { "git.exe", "C:\\Program Files\\Git\\bin\\git.exe" },
    },
    download = nil,
    post_msg = "Install Git: https://git-scm.com/download/" .. OS,
  },
  gradle = {
    label = "Gradle", desc = "Build tool Android (min 8)",
    bin = (OS == "windows") and "gradle.exe" or "gradle",
    hint = "Install Gradle atau pakai ./gradlew project.",
    url = "https://gradle.org/install",
    ver_arg = "--version",
    check_paths = {
      linux   = { "gradle", "~/.local/bin/gradle", "/usr/bin/gradle", "/usr/local/bin/gradle" },
      macos   = { "gradle", "~/.local/bin/gradle", "/usr/bin/gradle", "/usr/local/bin/gradle" },
      windows = { "gradle.exe", "C:\\Gradle\\bin\\gradle.exe" },
    },
    download = {
      linux   = { url = "https://services.gradle.org/distributions/gradle-" .. GRADLE_VER .. "-bin.zip", file = "gradle.zip", dir = "gradle-" .. GRADLE_VER, sha256_url = "https://services.gradle.org/distributions/gradle-" .. GRADLE_VER .. "-bin.zip.sha256" },
      macos   = { url = "https://services.gradle.org/distributions/gradle-" .. GRADLE_VER .. "-bin.zip", file = "gradle.zip", dir = "gradle-" .. GRADLE_VER, sha256_url = "https://services.gradle.org/distributions/gradle-" .. GRADLE_VER .. "-bin.zip.sha256" },
      windows = { url = "https://services.gradle.org/distributions/gradle-" .. GRADLE_VER .. "-bin.zip", file = "gradle.zip", dir = "gradle-" .. GRADLE_VER, sha256_url = "https://services.gradle.org/distributions/gradle-" .. GRADLE_VER .. "-bin.zip.sha256" },
    },
  },
  emulator = {
    label = "Emulator", desc = "Android Emulator binary (opsional, untuk AVD)",
    bin = (OS == "windows") and "emulator.exe" or "emulator",
    hint = "Install via Android Studio SDK Manager → SDK Tools → Android Emulator.",
    url = "https://developer.android.com/studio#command-line-tools-only",
    ver_arg = "--version",
    optional = true,
    check_paths = {
      linux   = { "emulator", "~/Android/Sdk/emulator/emulator", "~/android/emulator/emulator" },
      macos   = { "emulator", "~/Library/Android/sdk/emulator/emulator", "~/Android/Sdk/emulator/emulator" },
      windows = { "emulator.exe", "~/AppData/Local/Android/Sdk/emulator/emulator.exe" },
    },
    download = nil,
    post_msg = "Install Android SDK Emulator via Android Studio SDK Manager.",
  },
}

function M.get_tools_spec()
  return TOOLS
end

function M.get_os()
  return OS, ARCH
end

-- ── cari binary ──
local function find_tool(name)
  local spec = TOOLS[name]
  if not spec then return nil end

  local exe = vim.fn.exepath(spec.check_paths[OS][1])
  if exe and exe ~= "" then
    return { found = true, path = exe }
  end

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

  return { found = false, path = nil }
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

-- ── public check ──
function M.check_tool(name)
  local spec = TOOLS[name]
  if not spec then return { found = false, label = name, status = "missing" } end
  local r = find_tool(name)
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

function M.check_all(only)
  M.results = {}
  if not only then
    local ok, c = pcall(function() return require("anvim.config").get() end)
    if ok and c and c.health_check and c.health_check.tools then
      only = c.health_check.tools
    else
      only = { "adb", "java", "flutter", "git", "gradle" }
    end
  end
  for _, name in ipairs(only) do
    M.check_tool(name)
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

-- ── UI state ──
M._ui = { buf = nil, win = nil, items = {}, selected = 1 }

local function ui_close()
  util.close_win_buf(M._ui.win, M._ui.buf)
  M._ui.buf, M._ui.win, M._ui.items, M._ui.selected = nil, nil, {}, 1
end

local function ui_rebuild()
  M.check_all()
  local items = {}
  for _, name in ipairs(util.sorted_tool_names(M.results)) do
    local r = M.results[name]
    local kind = "info"
    if not r.found and r.can_download then kind = "installable"
    elseif not r.found then kind = "manual" end
    table.insert(items, { name = name, result = r, kind = kind })
  end
  M._ui.items = items
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
  local hl = {}
  for i, it in ipairs(M._ui.items) do
    local sel = (i == M._ui.selected) and "→ " or "  "
    local line = sel .. M.format_line(it.name, it.result)
    if #line > width then line = line:sub(1, width - 3) .. "..." end
    table.insert(lines, line)
    local grp = it.result.status == "ok" and "AnvimOk"
      or it.result.status == "old" and "AnvimWarn" or "AnvimError"
    table.insert(hl, { line = #lines, group = (i == M._ui.selected) and "AnvimSelected" or grp })
  end
  table.insert(lines, string.rep("─", width - 2))
  table.insert(lines, "Enter Install/Open  i Install all  q Quit")
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  pcall(require, "anvim.theme")
  for _, h in ipairs(hl) do
    pcall(vim.api.nvim_buf_add_highlight, buf, -1, h.group, h.line - 1, 0, -1)
  end
end

local function ui_install_queue(names, on_all_done)
  local ins_ok, ins = pcall(require, "anvim.installation")
  if not ins_ok then
    alert.error("install", "modul installation gagal load")
    if on_all_done then on_all_done(false) end
    return
  end
  ins.install_cancelled = false
  local idx = 1
  local function next()
    if ins.install_cancelled then
      ins.install_cancelled = false
      ui_rebuild()
      ui_render()
      if on_all_done then on_all_done(false) end
      return
    end
    if idx > #names then
      alert.ok("All downloads complete! Tools ready.")
      ui_rebuild()
      ui_render()
      if on_all_done then on_all_done(true) end
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
    ui_close()
    ins.install_tool(tool, dl, spec.label, spec.bin, function(ok_done)
      idx = idx + 1
      if not ok_done then
        alert.error("install", tool .. " gagal — chain berhenti")
        vim.schedule(function()
          M.interactive()
          if on_all_done then on_all_done(false) end
        end)
        return
      end
      vim.schedule(function()
        M.interactive()
        -- lanjutkan queue di UI baru
        local rest = {}
        for j = idx, #names do table.insert(rest, names[j]) end
        if #rest > 0 then
          ui_install_queue(rest, on_all_done)
        elseif on_all_done then
          on_all_done(true)
        end
      end)
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
    alert.warn((r.label or it.name) .. " harus install manual.\n" .. (r.post_msg or r.hint or ""))
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
    alert.info("Tidak ada tool yang bisa di-download otomatis.")
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
  ui_rebuild()

  local missing = M.get_missing()
  local outdated = M.get_outdated()
  if #missing == 0 and #outdated == 0 then
    alert.ok("All tools detected")
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
  vim.api.nvim_buf_set_name(buf, "anvim://system-check")
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
