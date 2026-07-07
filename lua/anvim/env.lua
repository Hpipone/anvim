-- anvim: .env file loader
-- ponytail: reads key=val lines, no parser lib

local M = {}

function M.load()
  local f = io.open(".env", "r")
  if not f then return {} end

  local env = {}
  for line in f:lines() do
    local key, val = line:match("^(%w+)=(.+)$")
    if key and val then
      env[key] = vim.trim(val)
      vim.env[key] = vim.env[key] or env[key]
    end
  end
  f:close()
  return env
end

return M
