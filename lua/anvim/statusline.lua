-- anvim: statusline — component ringan untuk statusline/lualine.
-- Pakai: lualine sections = { lualine_x = { require("anvim.statusline").lualine } }
-- atau: vim.o.statusline = "%!v:lua.require'anvim.statusline'.render()".

local M = {}

--- String ringkas: "◈ proj • device • task…". Aman dipanggil tiap redraw.
function M.text()
  local ok, parts = pcall(function()
    local segs = {}
    local pok, proj = pcall(function() return require("anvim.project").detect() end)
    if pok and proj and proj.type ~= "unknown" then
      table.insert(segs, proj.name .. " (" .. proj.type .. ")")
    end
    local dok, dev = pcall(require, "anvim.devices")
    if dok and dev.get_active() then
      table.insert(segs, dev.get_active())
    end
    local tok, tasks = pcall(require, "anvim.tasks")
    if tok and tasks.state.running then
      table.insert(segs, "▶ " .. tostring(tasks.state.current))
    end
    return table.concat(segs, " • ")
  end)
  if ok then return parts end
  return ""
end

function M.render()
  local t = M.text()
  return t ~= "" and ("anvim: " .. t) or ""
end

function M.lualine()
  return M.text()
end

return M
