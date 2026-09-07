-- anvim: flutter devices — list target via `flutter devices --machine` (JSON).

local M = {}

--- Parse output --machine (satu JSON object/array per baris) → {{id,name,platform}}.
function M._parse_machine(out)
  local devs = {}
  if not out or out == "" then return devs end
  local decode = vim.json and vim.json.decode or nil
  for line in out:gmatch("[^\r\n]+") do
    local t = vim.trim(line)
    if t:sub(1, 1) == "{" or t:sub(1, 1) == "[" then
      local ok, val = pcall(decode, t)
      if ok and val then
        local list = val
        if val.id then list = { val } end
        if type(list) == "table" then
          for _, d in ipairs(list) do
            if type(d) == "table" and d.id then
              table.insert(devs, {
                id = tostring(d.id),
                name = d.name or tostring(d.id),
                platform = d.targetPlatform or d.platform or "?",
              })
            end
          end
        end
      end
    end
  end
  return devs
end

--- List flutter devices (kosong jika flutter hilang / gagal).
--- Di-cache 30 detik karena `flutter devices` lambat (startup detik).
M._cache = { at = nil, data = {} }

function M.list()
  local now = vim.uv.now()
  if M._cache.at and now - M._cache.at < 30000 and M._cache.data then
    return M._cache.data
  end
  local devs = {}
  if vim.fn.executable("flutter") == 1 then
    local ok, out = pcall(vim.fn.system, "flutter devices --machine 2>/dev/null")
    if ok and out then devs = M._parse_machine(out) end
  end
  M._cache = { at = now, data = devs }
  return devs
end

return M
