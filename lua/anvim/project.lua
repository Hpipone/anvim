-- anvim: project type detection (git-root aware, monorepo safe)

local M = {}
local alert = require("anvim.status-alert")
local util = require("anvim.util")

local function root()
  local ok, r = pcall(util.project_root)
  if ok and r and r ~= "" then return r end
  return vim.fn.getcwd()
end

local function has_file_abs(path)
  return vim.fn.filereadable(path) == 1
end

local function join(a, b)
  if a:sub(-1) == "/" then return a .. b end
  return a .. "/" .. b
end

local function read_lines(path, max_lines)
  local lines = {}
  local f = io.open(path, "r")
  if not f then return lines end
  local n = 0
  for line in f:lines() do
    table.insert(lines, line)
    n = n + 1
    if max_lines and n >= max_lines then break end
  end
  f:close()
  return lines
end

local function git_branch(r)
  local ok, out = pcall(vim.fn.system, "git -C " .. util.esc(r) .. " rev-parse --abbrev-ref HEAD 2>/dev/null")
  if ok and out and vim.trim(out) ~= "" and not vim.trim(out):match("fatal") then
    return vim.trim(out):gsub("\n.*$", "")
  end
  return nil
end

function M.detect()
  local ok, result = pcall(function()
    local r = root()
    if has_file_abs(join(r, "pubspec.yaml")) then return M.detect_flutter(r) end
    if has_file_abs(join(r, "settings.gradle")) or has_file_abs(join(r, "settings.gradle.kts"))
      or has_file_abs(join(r, "build.gradle")) or has_file_abs(join(r, "build.gradle.kts")) then
      return M.detect_android(r)
    end
    -- fallback cwd-relatif (legacy, untuk test & non-git)
    if vim.fn.filereadable("pubspec.yaml") == 1 then return M.detect_flutter(vim.fn.getcwd()) end
    if vim.fn.filereadable("settings.gradle") == 1 or vim.fn.filereadable("build.gradle") == 1 then
      return M.detect_android(vim.fn.getcwd())
    end
    return nil
  end)
  if not ok then
    alert.error("project detect", result)
  end
  if not ok or result == nil then
    local r = root()
    return {
      type = "unknown",
      name = vim.fn.fnamemodify(r, ":t"),
      root = r,
      branch = git_branch(r),
      build_tool = nil, package = nil, version = nil,
    }
  end
  return result
end

function M.detect_flutter(r)
  r = r or root()
  local name = vim.fn.fnamemodify(r, ":t")
  local pkg, ver = nil, nil
  local pub = join(r, "pubspec.yaml")
  if has_file_abs(pub) then
    for _, line in ipairs(read_lines(pub, 60)) do
      local code = line:gsub("#.*$", "")
      local n = code:match('^%s*name:%s*["\']?([^"\'%s]+)["\']?%s*$')
      if n then name = vim.trim(n) end
      local v = code:match('^%s*version:%s*["\']?([^"\'%s]+)["\']?%s*$')
      if v then ver = vim.trim(v) end
    end
  end
  return { type = "flutter", name = name, root = r, branch = git_branch(r), build_tool = "flutter", package = pkg or name, version = ver }
end

function M.detect_android(r)
  r = r or root()
  local name = vim.fn.fnamemodify(r, ":t")
  local gradlew_abs = join(r, "gradlew")
  local build_tool = has_file_abs(gradlew_abs) and gradlew_abs or "gradle"
  -- jika gradlew tidak executable, fallback ke gradle PATH
  if build_tool == gradlew_abs and vim.fn.executable(gradlew_abs) ~= 1 and vim.fn.executable("gradle") == 1 then
    -- tetap pakai gradlew path absolut (sh akan exec via jobstart); biarkan, tapi catat
  end
  local pkg, ver = nil, nil
  for _, fname in ipairs({ "build.gradle", "build.gradle.kts", "app/build.gradle", "app/build.gradle.kts" }) do
    local p = join(r, fname)
    if has_file_abs(p) then
      for _, line in ipairs(read_lines(p, 200)) do
        local ns = line:match('namespace%s*[=%s]*["\']([^"\'%s]+)["\']') or line:match('applicationId%s*[=%s]*["\']([^"\'%s]+)["\']')
        if ns and not pkg then pkg = vim.trim(ns) end
        local vn = line:match('versionName%s*[=%s]*["\']([^"\'%s]+)["\']') or line:match('^%s*version%s*[=%s]*["\']([^"\'%s]+)["\']')
        if vn and not ver then ver = vim.trim(vn) end
      end
    end
  end
  return { type = "android", name = name, root = r, branch = git_branch(r), build_tool = build_tool, package = pkg, version = ver }
end

return M
