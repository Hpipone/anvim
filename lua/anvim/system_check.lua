-- anvim: system_check — detect OS, cek tools, rekomendasi download
-- human-readable: "Check System Tools" bukan "Health Check"

local M = {}
M.results = {}
local alert = require("anvim.status-alert")

-- ── OS detection ──
local OS = vim.uv.os_uname().sysname:lower()
if OS:find("windows") or OS:find("win32") then OS = "windows"
elseif OS:find("darwin") then OS = "macos"
else OS = "linux" end

local ARCH = vim.uv.os_uname().machine:lower()
if ARCH == "aarch64" or ARCH == "arm64" then ARCH = "arm64"
elseif ARCH == "x86_64" or ARCH == "amd64" then ARCH = "x86_64"
end

-- ── tool definitions ──
local TOOLS = {
  adb = {
    label = "ADB", desc = "Android Debug Bridge — komunikasi device",
    bin = (OS == "windows") and "adb.exe" or "adb",
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
  },
  java = {
    label = "Java", desc = "Java Runtime — Gradle build Android",
    bin = (OS == "windows") and "java.exe" or "java",
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
  },
  git = {
    label = "Git", desc = "Version control — info branch & project version",
    bin = (OS == "windows") and "git.exe" or "git",
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
  },
}

-- ── cari binary ──
local function find_tool(name)
  local spec = TOOLS[name]
  if not spec then return nil end

  local exe = vim.fn.exepath(spec.check_paths[OS][1])
  if exe and exe ~= "" then
    return { found = true, path = exe }
  end

  for _, p in ipairs(spec.check_paths[OS]) do
    if not p:find("*") then
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

-- ── public check ──
function M.check_tool(name)
  local spec = TOOLS[name]
  if not spec then return { found = false, label = name } end
  local r = find_tool(name)
  r.label = spec.label
  r.desc = spec.desc
  r.can_download = spec.download ~= nil
  r.name = name
  r.bin = spec.bin
  r.download = spec.download
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
  for name, r in pairs(M.results) do
    if not r.found then table.insert(missing, name) end
  end
  return missing
end

function M.format_line(name, r)
  if r.found then return "✓ " .. r.path end
  return "✗ Not found"
end

-- ── interactive check + multi-select download ──
function M.interactive()
  M.check_all()

  -- build report + floating window
  local buf = vim.api.nvim_create_buf(false, true)
  local width = 57
  local height = math.min(#M.results + 8, 25)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = width, height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
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
    if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
  end

  local report = { "╭───── anvim System Check ─────────────────────────────╮" }
  table.insert(report, "│ OS: " .. string.format("%-8s", OS:upper()) .. "  Arch: " .. ARCH .. "                   │")
  local missing = {}
  for name, r in pairs(M.results) do
    if r.found then
      local p = r.path:len() > 40 and "..." .. r.path:sub(-37) or r.path
      table.insert(report, "│  ✓ " .. string.format("%-10s", r.label) .. p .. string.rep(" ", 17) .. "│")
    else
      table.insert(missing, name)
      table.insert(report, "│  ✗ " .. string.format("%-10s", r.label) .. "not found" .. string.rep(" ", 17) .. "│")
    end
  end
  if #missing == 0 then
    table.insert(report, "│                                                       │")
    table.insert(report, "│  ✅ ALL GOOD                                          │")
  else
    table.insert(report, "├───────────────────────────────────────────────────────┤")
    table.insert(report, "│  ⚠ " .. #missing .. " tool(s) need install" .. string.rep(" ", 30 - #tostring(#missing)) .. "│")
  end
  table.insert(report, "╰───────────────────────────────────────────────────────╯")
  set_content(report)

  if #missing == 0 then
    vim.defer_fn(function()
      vim.notify("All tools detected", vim.log.levels.INFO)
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
      table.insert(menu, "    -  " .. spec.label .. " — " .. (spec.post_msg or "Install manually"))
    end
  end
  table.insert(menu, "")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, menu)
  vim.bo[buf].modifiable = false

  if #dl_list == 0 then
    close_win()
    vim.notify("All missing tools must be installed manually", vim.log.levels.WARN)
    return
  end

  -- prompt pake command-line input
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
      vim.notify("All downloads complete! Tools ready.", vim.log.levels.INFO)
      vim.schedule(function() pcall(require("anvim.dashboard").open) end)
      return
    end
    local tool = picks[idx]
    local spec = TOOLS[tool]
    local dl = spec.download[OS]
    ins.install_tool(tool, dl, spec.label, spec.bin, function()
      idx = idx + 1
      vim.schedule(next_install)
    end)
  end

  next_install()
end

return M
