-- anvim test runner
-- Usage: nvim --headless -l tests/run.lua

package.path = "lua/?.lua;lua/?/init.lua;" .. package.path

local results = { pass = 0, fail = 0, errors = {} }

-- Mock manager: temporarily patch vim.* paths, restore after
local function mock_mgr()
  local saved = {}

  if not vim.uv then vim.uv = {} end
  if not vim.loop then vim.loop = vim.uv end
  if not vim.fn then vim.fn = {} end
  if not vim.api then vim.api = {} end
  vim.bo = setmetatable({}, { __index = function(t, k) local v = {}; rawset(t, k, v); return v end })
  vim.wo = setmetatable({}, { __index = function(t, k) local v = {}; rawset(t, k, v); return v end })
  if not vim.o then vim.o = {} end
  if not vim.env then vim.env = {} end
  if not vim.g then vim.g = {} end
  if not vim.log then vim.log = {} end
  if not vim.keymap then vim.keymap = {} end
  if not vim.trim then
    vim.trim = function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
  end
  if not vim.list_extend then
    vim.list_extend = function(dst, src)
      for _, v in ipairs(src or {}) do table.insert(dst, v) end
      return dst
    end
  end
  if not vim.tbl_deep_extend then
    vim.tbl_deep_extend = function(_, ...)
      local out = {}
      for i = 1, select("#", ...) do
        local t = select(i, ...)
        if type(t) == "table" then
          for k, v in pairs(t) do out[k] = v end
        end
      end
      return out
    end
  end
  if not vim.fn.bufwinid then vim.fn.bufwinid = function() return -1 end end

  return {
    set = function(_) end,
    raw = function(path, value)
      local parts = {}
      for part in path:gmatch("[^%.]+") do table.insert(parts, part) end
      local last = table.remove(parts)
      local obj = vim
      for _, p in ipairs(parts) do
        if obj[p] == nil then obj[p] = {} end
        obj = obj[p]
      end
      -- mirror uv<->loop agar mock dua-duanya
      if parts[1] == "uv" or parts[1] == "loop" then
        local other = parts[1] == "uv" and "loop" or "uv"
        if vim[other] == nil then vim[other] = {} end
        if saved[other .. "." .. last] == nil then saved[other .. "." .. last] = vim[other][last] end
        vim[other][last] = value
      end
      if saved[path] == nil then saved[path] = obj[last] end
      obj[last] = value
    end,
    restore_all = function()
      for path, value in pairs(saved) do
        local parts = {}
        for part in path:gmatch("[^%.]+") do table.insert(parts, part) end
        local last = table.remove(parts)
        local obj = vim
        for _, p in ipairs(parts) do
          if obj[p] == nil then obj[p] = {} end
          obj = obj[p]
        end
        obj[last] = value
      end
      saved = {}
    end,
  }
end

local function run_test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    results.pass = results.pass + 1
    io.write("  ✓ " .. name .. "\n")
  else
    results.fail = results.fail + 1
    table.insert(results.errors, { name = name, err = err })
    io.write("  ✗ " .. name .. ": " .. tostring(err) .. "\n")
  end
end

local suites = {
  "tests.test_util",
  "tests.test_config",
  "tests.test_installation",
  "tests.test_dashboard",
  "tests.test_system_check",
  "tests.test_logcat",
  "tests.test_devices",
  "tests.test_tasks",
  "tests.test_project",
  "tests.test_init",
  "tests.test_health",
}

for _, mod in ipairs(suites) do
  io.write("\n── " .. mod:gsub("^tests%.", "") .. " ──\n")
  local m = mock_mgr()
  local ok, fn = pcall(require, mod)
  if ok then
    local ok2, err2 = pcall(fn, { mock = m, run = run_test })
    if not ok2 then
      io.write("  ✗ SUITE FAIL: " .. tostring(err2) .. "\n")
      results.fail = results.fail + 1
    end
  else
    io.write("  ✗ LOAD FAIL: " .. tostring(fn) .. "\n")
    results.fail = results.fail + 1
    table.insert(results.errors, { name = mod, err = fn })
  end
  m.restore_all()
  for k in pairs(package.loaded) do
    if k:match("^anvim%.") or k:match("^tests%.") then
      package.loaded[k] = nil
    end
  end
end

io.write(string.format("\n── Results: %d pass, %d fail ──\n", results.pass, results.fail))
if results.fail > 0 then
  for _, e in ipairs(results.errors) do
    io.write("  " .. e.name .. ": " .. tostring(e.err) .. "\n")
  end
  os.exit(1)
end
