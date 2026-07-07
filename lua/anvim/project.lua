-- anvim: project type detection

local M = {}

local function has_file(name)
  return vim.fn.filereadable(name) == 1
end

function M.detect()
  if has_file("pubspec.yaml") then
    return M.detect_flutter()
  end
  if has_file("settings.gradle") or has_file("settings.gradle.kts") or has_file("build.gradle") then
    return M.detect_android()
  end

  return {
    type = "unknown",
    name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t"),
    build_tool = nil,
    package = nil,
    version = nil,
  }
end

function M.detect_flutter()
  local name = "unknown"
  local pkg, ver = nil, nil

  -- Try pubspec.yaml for name/version
  if has_file("pubspec.yaml") then
    for line in io.lines("pubspec.yaml") do
      local n = line:match('^name:%s*(.+)$')
      if n then name = vim.trim(n) end
      local v = line:match('^version:%s*(.+)$')
      if v then ver = vim.trim(v) end
    end
  end

  return {
    type = "flutter",
    name = name,
    build_tool = "flutter",
    package = pkg,
    version = ver,
  }
end

function M.detect_android()
  local name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  local build_tool = has_file("gradlew") and "./gradlew" or "gradle"
  local pkg, ver = nil, nil

  -- Quick scan build.gradle for package/version
  for _, f in ipairs({ "build.gradle", "app/build.gradle" }) do
    if has_file(f) then
      for line in io.lines(f) do
        local ns = line:match('namespace%s+(.+)$')
        if ns then pkg = ns end
        local vn = line:match("versionName%s+(.+)$")
        if vn then ver = vn end
      end
    end
  end

  return {
    type = "android",
    name = name,
    build_tool = build_tool,
    package = pkg,
    version = ver,
  }
end

return M
