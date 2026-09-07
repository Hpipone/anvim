-- test_project.lua

return function(ctx)
  local mock = ctx.mock
  local run = ctx.run

  run("project: strip quotes pubspec", function()
    mock.raw("fn.system", function(cmd)
      cmd = tostring(cmd)
      if cmd:find("rev%-parse") then return "/tmp/myapp\n" end
      return ""
    end)
    mock.raw("fn.getcwd", function() return "/tmp/myapp" end)
    mock.raw("fn.isdirectory", function() return 1 end)
    mock.raw("fn.filereadable", function(name)
      if tostring(name):find("pubspec") then return 1 end
      return 0
    end)
    mock.raw("log.levels", { INFO = 0, WARN = 1, ERROR = 2, DEBUG = 3 })
    package.loaded["anvim.status-alert"] = { debug = function() end, error = function() end, info = function() end, warn = function() end, ok = function() end }
    local orig_open = io.open
    io.open = function(path, _)
      if tostring(path):find("pubspec") then
        local lines = { 'name: "my_app"', "version: '1.0.0+1' # comment" }
        local i = 0
        return { lines = function() return function()
          i = i + 1 return lines[i]
        end end, close = function() end }
      end
      return orig_open(path, _)
    end
    package.loaded["anvim.project"] = nil
    package.loaded["anvim.util"] = nil
    local p = require("anvim.project")
    local r = p.detect_flutter("/tmp/myapp")
    assert(r.name == "my_app", "got " .. tostring(r.name))
    assert(r.version == "1.0.0+1", "got " .. tostring(r.version))
    io.open = orig_open
  end)

  run("project: unknown fallback ada root+branch", function()
    mock.raw("fn.filereadable", function() return 0 end)
    mock.raw("fn.system", function() return "main\n" end)
    package.loaded["anvim.project"] = nil
    package.loaded["anvim.util"] = nil
    local p = require("anvim.project")
    local r = p.detect()
    assert(r.type == "unknown")
    assert(r.root ~= nil and r.root ~= "")
  end)

  run("project: detect node + scripts", function()
    mock.raw("fn.filereadable", function(name)
      if tostring(name):find("package.json") then return 1 end
      return 0
    end)
    mock.raw("fn.system", function() return "main\n" end)
    local orig_open = io.open
    io.open = function(path, mode)
      if tostring(path):find("package.json") then
        return { read = function() return '{"name":"myapp","version":"1.2.3","scripts":{"dev":"expo start","build":"expo build","test":"jest"}}' end, close = function() end }
      end
      return orig_open(path, mode)
    end
    package.loaded["anvim.project"] = nil
    package.loaded["anvim.util"] = nil
    local p = require("anvim.project")
    local r = p.detect_node("/tmp/myapp")
    assert(r.type == "node" and r.name == "myapp", "got " .. r.type .. "/" .. r.name)
    assert(r.scripts.dev == "expo start" and r.scripts.build == "expo build")
    io.open = orig_open
  end)
end
