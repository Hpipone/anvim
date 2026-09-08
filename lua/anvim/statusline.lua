-- anvim: statusline — component ringan untuk statusline/lualine.
-- Pakai: lualine sections = { lualine_x = { require("anvim.statusline").lualine } }
-- atau: vim.o.statusline = "%!v:lua.require'anvim.statusline'.render()".
-- detect() yang berat (git fork + io) di-cache; invalidate saat pindah
-- direktori/buffer agar tidak fork tiap redraw.

local M = {}

M._cache = { key = nil, text = "" }

local function cwd_key()
  local ok, cwd = pcall(vim.fn.getcwd)
  local ok2, buf = pcall(vim.api.nvim_get_current_buf)
  return (ok and cwd or "?") .. "#" .. (ok2 and tostring(buf) or "?")
end

local function compute()
  local segs = {}
  local pok, proj = pcall(function() return require("anvim.project").detect() end)
  if pok and proj and proj.type ~= "unknown" then
    table.insert(segs, proj.name .. " (" .. proj.type .. ")")
  end
  local dok, dev = pcall(require, "anvim.devices")
  local active = dok and dev.get_active and dev.get_active() or nil
  if active and active ~= "" then
    table.insert(segs, active)
  end
  local tok, tasks = pcall(require, "anvim.tasks")
  if tok and tasks.state and tasks.state.running then
    table.insert(segs, "▶ " .. tostring(tasks.state.current))
  end
  return table.concat(segs, " • ")
end

--- String ringkas: "proj • device • task…". Aman dipanggil tiap redraw.
function M.text()
  local ok, text = pcall(function()
    local key = cwd_key()
    -- task running berubah tiap saat → jangan sajikan cache basi
    local tok, tasks = pcall(require, "anvim.tasks")
    local running = tok and tasks.state and tasks.state.running
    if not running and M._cache.key == key then
      return M._cache.text
    end
    local t = compute()
    if not running then
      M._cache = { key = key, text = t }
    end
    return t
  end)
  if ok and type(text) == "string" then return text end
  return ""
end

--- Paksa hitung ulang berikutnya (dipanggil autocmd DirChanged/BufEnter).
function M.invalidate()
  M._cache.key = nil
end

function M.render()
  local t = M.text()
  return t ~= "" and ("anvim: " .. t) or ""
end

function M.lualine()
  return M.text()
end

-- auto-invalidate agar cache tidak basi
pcall(vim.api.nvim_create_augroup, "AnvimStatusline", { clear = true })
pcall(vim.api.nvim_create_autocmd, { "DirChanged", "BufEnter" }, {
  group = "AnvimStatusline",
  callback = function() M.invalidate() end,
})

return M
