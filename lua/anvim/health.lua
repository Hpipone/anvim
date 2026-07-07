-- anvim: system health check
-- ponytail: exepath-based, no external runtime deps

local M = {}

local checks = {
  adb = {
    label = "ADB",
    cmd = "adb",
    required_for = { "android", "flutter" },
    hint = "Install Android SDK Platform-Tools or set PATH.",
    url = "https://developer.android.com/studio/command-line",
  },
  java = {
    label = "Java",
    cmd = "java",
    required_for = { "android" },
    hint = "Install OpenJDK 11 or higher.",
    url = "https://adoptium.net",
  },
  flutter = {
    label = "Flutter",
    cmd = "flutter",
    required_for = { "flutter" },
    hint = "Install Flutter SDK and set PATH.",
    url = "https://flutter.dev/docs/get-started/install",
  },
  git = {
    label = "Git",
    cmd = "git",
    required_for = { "android", "flutter" },
    hint = "Install Git from your package manager.",
    url = "https://git-scm.com/downloads",
  },
}

--- Run all tool checks.
--- Returns { tools = { name = { found, path, version } }, summary = { ok, warn, err } }
function M.check_all()
  local results = {}
  local summary = { ok = 0, warn = 0, err = 0 }

  for name, spec in pairs(checks) do
    local r = check_tool(spec)
    r.name = name
    results[name] = r
    if r.found then
      summary.ok = summary.ok + 1
    else
      summary.err = summary.err + 1
    end
  end

  return { tools = results, summary = summary, timestamp = vim.fn.strftime("%H:%M:%S") }
end

--- Run check for configured tools only.
function M.check_configured(enabled_list)
  local all = M.check_all()
  if not enabled_list then
    return all
  end
  local filtered = {}
  local summary = { ok = 0, warn = 0, err = 0 }
  for _, name in ipairs(enabled_list) do
    local r = all.tools[name]
    if r then
      filtered[name] = r
      if r.found then summary.ok = summary.ok + 1 else summary.err = summary.err + 1 end
    end
  end
  return { tools = filtered, summary = summary, timestamp = all.timestamp }
end

function M.get_checks_spec()
  return checks
end

function M.get_missing(results)
  local missing = {}
  for name, r in pairs(results.tools) do
    if not r.found then
      table.insert(missing, { name = name, spec = checks[name] })
    end
  end
  return missing
end

--- Format single tool status line.
function M.format_line(name, r)
  local icon = r.found and "✓" or "✗"
  local label = (checks[name] and checks[name].label) or name
  if r.found then
    return string.format("[%s] %s found at %s", icon, label, r.path)
  end
  return string.format("[%s] %s not found — %s", icon, label, checks[name] and checks[name].hint or "")
end

local function check_tool(spec)
  local path = vim.fn.exepath(spec.cmd)
  if path and path ~= "" then
    local ok, out = pcall(vim.fn.system, spec.cmd .. " --version 2>/dev/null | head -1")
    local version = ok and out ~= "" and vim.trim(out) or ""
    return { found = true, path = path, version = version }
  end
  return { found = false, path = nil, version = nil }
end

return M
