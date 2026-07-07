-- anvim: self-check
-- ponytail: single assert-based test, no test framework
-- Run: nvim --headless -c "luafile test_anvim.lua" -c "qa!"

package.path = "lua/?.lua;" .. package.path

local function reload(name)
  package.loaded[name] = nil
  return require(name)
end

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    print("  PASS: " .. name)
  else
    print("  FAIL: " .. name .. " — " .. tostring(err))
  end
end

print("anvim self-check:")
print("")

-- config
test("config defaults", function()
  local c = require("anvim.config")
  local cfg = c.setup({})
  assert(cfg.dashboard.width == 0.8, "width default")
  assert(cfg.dashboard.border == "rounded", "border default")
end)

-- health
test("health check spec", function()
  local h = require("anvim.health")
  local spec = h.get_checks_spec()
  assert(spec.adb ~= nil, "adb in spec")
  assert(spec.java ~= nil, "java in spec")
  assert(spec.git ~= nil, "git in spec")
end)

test("format line for found tool", function()
  local h = require("anvim.health")
  local line = h.format_line("adb", { found = true, path = "/usr/bin/adb", version = "" })
  assert(line:match("✓"), "should show checkmark")
  assert(line:match("/usr/bin/adb"), "should show path")
end)

test("format line for missing tool", function()
  local h = require("anvim.health")
  local line = h.format_line("adb", { found = false, path = nil, version = nil })
  assert(line:match("✗"), "should show cross")
  assert(line:match("ADB not found"), "should show hint")
end)

-- project
test("project detect unknown", function()
  local p = reload("anvim.project")
  -- In an empty dir with no build files
  local r = p.detect()
  assert(r.type == "unknown", "type should be unknown")
end)

test("project detect android", function()
  local f = io.open("build.gradle", "w")
  assert(f)
  f:write('android { namespace "com.example.app" }\n')
  f:close()
  local p = reload("anvim.project")
  local r = p.detect()
  assert(r.type == "android", "type should be android")
  assert(r.build_tool == "gradle", "build_tool fallback")
  os.remove("build.gradle")
end)

test("project detect flutter", function()
  local f = io.open("pubspec.yaml", "w")
  assert(f)
  f:write("name: my_flutter_app\nversion: 1.2.3\n")
  f:close()
  local p = reload("anvim.project")
  local r = p.detect()
  assert(r.type == "flutter", "type should be flutter")
  assert(r.name == "my_flutter_app", "name from pubspec")
  assert(r.version == "1.2.3", "version from pubspec")
  os.remove("pubspec.yaml")
end)

-- devices
test("devices state", function()
  local d = reload("anvim.devices")
  d.set_active("emulator-5554")
  assert(d.get_active() == "emulator-5554", "active device set")
end)

test("device format", function()
  local d = reload("anvim.devices")
  local line = d.format({ id = "emulator-5554", status = "device", model = "Pixel_4" })
  assert(line:match("Pixel_4"), "should show model")
  assert(line:match("device"), "should show status")
end)

-- env
test("env loader handles missing file", function()
  local e = require("anvim.env")
  local r = e.load()
  assert(type(r) == "table", "returns table")
end)

-- tasks
test("tasks state init", function()
  local t = reload("anvim.tasks")
  assert(t.state.running == false, "not running")
  assert(t.state.current == nil, "no current task")
end)

print("")
print("Done. All tests that passed above are OK.")
