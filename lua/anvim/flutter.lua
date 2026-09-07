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
function M.list()
  if vim.fn.executable("flutter") == 0 then return {} end
  local ok, out = pcall(vim.fn.system, "flutter devices --machine 2>/dev/null")
  if not ok or not out then return {} end
  return M._parse_machine(out)
end

return M
