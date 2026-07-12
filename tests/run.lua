-- anvim test runner
-- Usage: nvim --headless -l tests/run.lua
-- ponytail: plain assert, no framework, mock vim.* before require

package.path = "lua/?.lua;" .. package.path

local results = { pass = 0, fail = 0, errors = {} }

-- Mock manager: temporarily patch vim.* paths, restore after
local function mock_mgr()
  local saved = {}

  -- init nested vim structure so mock.raw("loop.os_uname",...) works
  if not vim.loop then vim.loop = {} end
  if not vim.fn then vim.fn = {} end
  if not vim.api then vim.api = {} end
  if not vim.bo then vim.bo = setmetatable({}, { __index = function(t,k) local v={}; rawset(t,k,v); return v end }) end
  if not vim.wo then vim.wo = setmetatable({}, { __index = function(t,k) local v={}; rawset(t,k,v); return v end }) end
  if not vim.o then vim.o = {} end
  if not vim.env then vim.env = {} end
  if not vim.g then vim.g = {} end
  if not vim.log then vim.log = {} end
  if not vim.keymap then vim.keymap = {} end
  if not vim._schedule_calls then vim._schedule_calls = {} end

  return {
    set = function(path, value)
      local obj = vim
      for part in path:gmatch("[^%.]+") do
        if obj == vim then
          -- skip first segment if it's "vim"
          if part == "vim" then obj = vim; else obj = obj[part] end
        else
          obj = obj[part]
        end
      end
      -- actually let me just use a simpler approach
    end,
    raw = function(path, value)
      local parts = {}
      for part in path:gmatch("[^%.]+") do table.insert(parts, part) end
      local last = table.remove(parts)
      local obj = vim
      for _, p in ipairs(parts) do obj = obj[p] end
      saved[path] = obj[last]
      obj[last] = value
    end,
    restore_all = function()
      for path, value in pairs(saved) do
        local parts = {}
        for part in path:gmatch("[^%.]+") do table.insert(parts, part) end
        local last = table.remove(parts)
        local obj = vim
        for _, p in ipairs(parts) do obj = obj[p] end
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
  "tests.test_installation",
  "tests.test_dashboard",
  "tests.test_system_check",
  "tests.test_logcat",
}

for _, mod in ipairs(suites) do
  io.write("\n── " .. mod:gsub("^tests%.", "") .. " ──\n")
  local m = mock_mgr()
  local ok, fn = pcall(require, mod)
  if ok then
    fn({ mock = m, run = run_test })
  else
    io.write("  ✗ LOAD FAIL: " .. tostring(fn) .. "\n")
    results.fail = results.fail + 1
    table.insert(results.errors, { name = mod, err = fn })
  end
  m.restore_all()
  -- clear module cache for next suite
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
