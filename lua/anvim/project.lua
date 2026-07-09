-- anvim: project type detection

local M = {}
local alert = require("anvim.status-alert")

local function has_file(name)
  return vim.fn.filereadable(name) == 1
end

function M.detect()
  local ok, result = pcall(function()
    if has_file("pubspec.yaml") then return M.detect_flutter() end
    if has_file("settings.gradle") or has_file("settings.gradle.kts") or has_file("build.gradle") then return M.detect_android() end
    return nil
  end)
  if not ok then
    alert.error("project detect", result)
  end
  if not ok or result == nil then
    return {
      type = "unknown",
      name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t"),
      build_tool = nil, package = nil, version = nil,
    }
  end
  return result
end

function M.detect_flutter()
  local name = "unknown"
  local pkg, ver = nil, nil
  if has_file("pubspec.yaml") then
    local f, open_err = io.open("pubspec.yaml", "r")
    if f then
      for line in f:lines() do
        local n = line:match('^name:%s*(.+)$')
        if n then name = vim.trim(n) end
        local v = line:match('^version:%s*(.+)$')
        if v then ver = vim.trim(v) end
      end
      f:close()
    else
      alert.debug("project", "buka pubspec.yaml gagal — " .. tostring(open_err))
    end
  end
  return { type = "flutter", name = name, build_tool = "flutter", package = pkg, version = ver }
end

function M.detect_android()
  local name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  local build_tool = has_file("gradlew") and "./gradlew" or "gradle"
  local pkg, ver = nil, nil
  for _, fname in ipairs({ "build.gradle", "app/build.gradle" }) do
    if has_file(fname) then
      local f, err = io.open(fname, "r")
      if f then
        for line in f:lines() do
          local ns = line:match('namespace%s+(.+)$')
          if ns then pkg = ns end
          local vn = line:match("versionName%s+(.+)$")
          if vn then ver = vn end
        end
        f:close()
      else
        alert.debug("project", "buka " .. fname .. " gagal — " .. tostring(err))
      end
    end
  end
  return { type = "android", name = name, build_tool = build_tool, package = pkg, version = ver }
end

return M
