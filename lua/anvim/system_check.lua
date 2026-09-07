-- anvim: system_check — detect OS, cek tools, rekomendasi download
-- human-readable: "Check System Tools" bukan "Health Check"
-- single source untuk health (health.lua adalah shim ke modul ini).

local M = {}
M.results = {}
local alert = require("anvim.status-alert")
local util = require("anvim.util")

local OS = util.OS
local ARCH = util.ARCH

-- ── tool definitions ──
-- sha256_url: official checksum. Gradle & Flutter publish .sha256;
-- platform-tools Google tidak publish checksum → sha256_url=nil (wajib manual verify dilewati dengan warning keras).
local TOOLS = {
  adb = {
    label = "ADB", desc = "Android Debug Bridge — komunikasi device",
    bin = (OS == "windows") and "adb.exe" or "adb",
    hint = "Install Android SDK Platform-Tools atau pakai :AnvimCheck auto-download.",
    url = "https://developer.android.com/studio/command-line",
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
    label = "Java", desc = "Java Runtime — Gradle build Android",
    bin = (OS == "windows") and "java.exe" or "java",
    hint = "Install OpenJDK 17+.",
    url = "https://adoptium.net",
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
    check_paths = {
      linux   = { "flutter", "~/flutter/bin/flutter", "/usr/local/flutter/bin/flutter", "/opt/flutter/bin/flutter", "~/.local/bin/flutter" },
      macos   = { "flutter", "~/flutter/bin/flutter", "/usr/local/flutter/bin/flutter", "/opt/homebrew/bin/flutter", "~/.local/bin/flutter" },
      windows = { "flutter.exe", "~/flutter/bin/flutter.exe", "C:\\flutter\\bin\\flutter.exe" },
    },
    download = {
      linux   = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.29.2-stable.tar.xz", file = "flutter.tar.xz", dir = "flutter", sha256_url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.29.2-stable.tar.xz.sha256" },
      macos   = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.29.2-stable.zip", file = "flutter.zip", dir = "flutter", sha256_url = nil },
      windows = { url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.29.2-stable.zip", file = "flutter.zip", dir = "flutter", sha256_url = nil },
    },
  },
  git = {
    label = "Git", desc = "Version control — info branch & project version",
    bin = (OS == "windows") and "git.exe" or "git",
    hint = "Install Git dari package manager.",
    url = "https://git-scm.com/downloads",
    check_paths = {
      linux   = { "git", "/usr/bin/git", "/usr/local/bin/git" },
      macos   = { "git", "/usr/bin/git", "/usr/local/bin/git" },
      windows = { "git.exe", "C:\\Program Files\\Git\\bin\\git.exe" },
    },
    download = nil,
    post_msg = "Install Git: https://git-scm.com/download/" .. OS,
  },
  gradle = {
    label = "Gradle", desc = "Build tool Android",
    bin = (OS == "windows") and "gradle.exe" or "gradle",
    hint = "Install Gradle atau pakai ./gradlew project.",
    url = "https://gradle.org/install",
    check_paths = {
      linux   = { "gradle", "~/.local/bin/gradle", "/usr/bin/gradle", "/usr/local/bin/gradle" },
      macos   = { "gradle", "~/.local/bin/gradle", "/usr/bin/gradle", "/usr/local/bin/gradle" },
      windows = { "gradle.exe", "C:\\Gradle\\bin\\gradle.exe" },
    },
    download = {
      linux   = { url = "https://services.gradle.org/distributions/gradle-8.10.2-bin.zip", file = "gradle.zip", dir = "gradle-8.10.2", sha256_url = "https://services.gradle.org/distributions/gradle-8.10.2-bin.zip.sha256" },
      macos   = { url = "https://services.gradle.org/distributions/gradle-8.10.2-bin.zip", file = "gradle.zip", dir = "gradle-8.10.2", sha256_url = "https://services.gradle.org/distributions/gradle-8.10.2-bin.zip.sha256" },
      windows = { url = "https://services.gradle.org/distributions/gradle-8.10.2-bin.zip", file = "gradle.zip", dir = "gradle-8.10.2", sha256_url = "https://services.gradle.org/distributions/gradle-8.10.2-bin.zip.sha256" },
    },
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

  if name == "adb" then
    local ah = vim.env.ANDROID_HOME or vim.env.ANDROID_SDK_ROOT
    if ah then
      for _, p in ipairs({ ah .. "/platform-tools/adb", ah .. "\\platform-tools\\adb.exe" }) do
        if vim.fn.executable(vim.fn.expand(p)) == 1 then
          return { found = true, path = vim.fn.expand(p) }
        end
      end
    end
  end

  return { found = false, path = nil }
end

local function tool_version(bin)
  if not bin or bin == "" then return "" end
  if not util.is_safe_bin_name(vim.fn.fnamemodify(bin, ":t")) and vim.fn.executable(bin) ~= 1 then
    -- bin adalah path; ambil basename untuk validasi longgar
  end
  local ok, out = pcall(vim.fn.system, util.esc(bin) .. " --version 2>/dev/null | head -1")
  if ok and out and vim.trim(out) ~= "" then
    return vim.trim(out):sub(1, 80)
  end
  return ""
end

-- ── public check ──
function M.check_tool(name)
  local spec = TOOLS[name]
  if not spec then return { found = false, label = name } end
  local r = find_tool(name)
  r.label = spec.label
  r.desc = spec.desc
  r.hint = spec.hint
  r.url = spec.url
  r.can_download = spec.download ~= nil
  r.name = name
  r.bin = spec.bin
  r.download = spec.download and spec.download[OS] or nil
  r.post_msg = spec.post_msg
  if r.found then
    r.version = tool_version(r.path ~= "" and r.path or spec.bin)
  end
  M.results[name] = r
  return r
end

function M.check_all(only)
  M.results = {}
  for _, name in ipairs(only or { "adb", "java", "flutter", "git", "gradle" }) do
    M.check_tool(name)
  end
  return M.results
end

function M.get_missing()
  local missing = {}
  for _, name in ipairs(util.TOOL_ORDER) do
    local r = M.results[name]
    if r and not r.found then table.insert(missing, name) end
  end
  for name, r in pairs(M.results) do
    local known = false
    for _, x in ipairs(util.TOOL_ORDER) do if x == name then known = true break end end
    if not known and not r.found then table.insert(missing, name) end
  end
  return missing
end

function M.format_line(name, r)
  local spec = TOOLS[name]
  local label = (r and r.label) or (spec and spec.label) or name
  if r and r.found then
    local v = r.version and r.version ~= "" and (" (" .. r.version .. ")") or ""
    return string.format("✓ %s found at %s%s", label, r.path, v)
  end
  local hint = (r and r.hint) or (spec and spec.hint) or ""
  if hint ~= "" then
    return string.format("✗ %s not found — %s", label, hint)
  end
  return string.format("✗ %s not found", label)
end

-- ── interactive check + multi-select download ──
function M.interactive()
  M.check_all()

  local buf = vim.api.nvim_create_buf(false, true)
  local n_results = util.tbl_count(M.results)
  local width = 57
  local height = math.min(n_results + 8, 25)
  local cols = vim.o.columns or 80
  local lines_n = vim.o.lines or 24
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = width, height = height,
    col = math.floor(math.max(0, (cols - width) / 2)),
    row = math.floor(math.max(0, (lines_n - height) / 2)),
    style = "minimal", border = "rounded",
    title = " System Check ", title_pos = "center",
  })
  vim.wo[win].winblend = 10

  local function set_content(lines)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
  end

  local function close_win()
    util.close_win_buf(win, buf)
  end

  local report = { "OS: " .. OS:upper() .. "  Arch: " .. ARCH }
  local missing = {}
  for _, name in ipairs(util.sorted_tool_names(M.results)) do
    local r = M.results[name]
    table.insert(report, M.format_line(name, r))
    if not r.found then table.insert(missing, name) end
  end
  if #missing == 0 then
    table.insert(report, "")
    table.insert(report, "ALL GOOD")
  else
    table.insert(report, "")
    table.insert(report, tostring(#missing) .. " tool(s) need install")
  end
  set_content(report)

  if #missing == 0 then
    vim.defer_fn(function()
      alert.ok("All tools detected")
      close_win()
      vim.schedule(function() pcall(require("anvim.dashboard").open) end)
    end, 1500)
    return
  end

  -- list downloadable
  local dl_list = {}
  vim.bo[buf].modifiable = true
  local menu = {}
  for _, l in ipairs(report) do table.insert(menu, l) end
  table.insert(menu, "")
  table.insert(menu, "  Tools available for auto-download:")
  for _, name in ipairs(missing) do
    local spec = TOOLS[name]
    if spec and spec.download and spec.download[OS] then
      table.insert(dl_list, name)
      table.insert(menu, "    " .. #dl_list .. ". " .. spec.label .. " — " .. spec.desc)
    else
      table.insert(menu, "    -  " .. spec.label .. " — " .. (spec.post_msg or spec.hint or "Install manually"))
    end
  end
  table.insert(menu, "")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, menu)
  vim.bo[buf].modifiable = false

  if #dl_list == 0 then
    close_win()
    alert.warn("All missing tools must be installed manually")
    return
  end

  vim.fn.inputsave()
  local raw = vim.fn.input("Pick tools (comma-separated, e.g. 1,2,3): ")
  vim.fn.inputrestore()

  close_win()

  if raw == "" or raw == "0" then
    vim.schedule(function() pcall(require("anvim.dashboard").open) end)
    return
  end

  local picks = {}
  for s in raw:gmatch("%d+") do
    local n = tonumber(s)
    if n and n >= 1 and n <= #dl_list then picks[#picks+1] = dl_list[n] end
  end

  if #picks == 0 then
    vim.schedule(function() pcall(require("anvim.dashboard").open) end)
    return
  end

  vim.fn.inputsave()
  local confirm = vim.fn.input("Confirm download " .. table.concat(picks, ", ") .. "? (y/n): ")
  vim.fn.inputrestore()
  if confirm:lower() ~= "y" then
    vim.schedule(function() pcall(require("anvim.dashboard").open) end)
    return
  end

  -- sequential install via installation module
  local ins = require("anvim.installation")
  ins.install_cancelled = false
  local idx = 1

  local function next_install()
    if ins.install_cancelled then
      ins.install_cancelled = false
      vim.schedule(function() pcall(require("anvim.dashboard").open) end)
      return
    end
    if idx > #picks then
      alert.ok("All downloads complete! Tools ready.")
      vim.schedule(function() pcall(require("anvim.dashboard").open) end)
      return
    end
    local tool = picks[idx]
    local spec = TOOLS[tool]
    local dl = spec.download[OS]
    ins.install_tool(tool, dl, spec.label, spec.bin, function(ok_done)
      idx = idx + 1
      if not ok_done then
        alert.error("install", tool .. " gagal — chain berhenti")
        vim.schedule(function() pcall(require("anvim.dashboard").open) end)
        return
      end
      vim.schedule(next_install)
    end)
  end

  next_install()
end

return M
