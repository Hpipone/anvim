-- anvim: util — shared OS/shell/fs helpers (single source)
-- Dipakai semua modul agar tidak duplikat deteksi OS/ARCH/shellescape.

local M = {}

--- Deteksi OS: "linux" | "macos" | "windows"
function M.detect_os(uname_sys)
  local s = (uname_sys or (vim.uv and vim.uv.os_uname and vim.uv.os_uname().sysname) or ""):lower()
  if s:find("windows") or s:find("win32") then return "windows" end
  if s:find("darwin") then return "macos" end
  return "linux"
end

--- Deteksi ARCH: "arm64" | "x86_64" | raw
function M.detect_arch(uname_machine)
  local a = (uname_machine or (vim.uv and vim.uv.os_uname and vim.uv.os_uname().machine) or ""):lower()
  if a == "aarch64" or a == "arm64" then return "arm64" end
  if a == "x86_64" or a == "amd64" then return "x86_64" end
  return a ~= "" and a or "x86_64"
end

M.OS = M.detect_os()
M.ARCH = M.detect_arch()

--- Validasi nama binary agar aman untuk shell (cegah injection via zip).
--- Hanya boleh [A-Za-z0-9._-], tolak path separator & shell metachars.
function M.is_safe_bin_name(name)
  if type(name) ~= "string" or name == "" then return false end
  if name:find("/") or name:find("\\") then return false end
  return name:match("^[%w%.%_%-]+$") ~= nil
end

--- shellescape wrapper (vim.fn.shellescape), fallback quote sederhana.
function M.esc(path)
  if vim.fn and vim.fn.shellescape then
    return vim.fn.shellescape(path)
  end
  return "'" .. tostring(path):gsub("'", "'\\''") .. "'"
end

--- Clamp number ke [lo, hi].
function M.clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

--- Hitung ukuran floating dari fraksi config + clamp layar kecil.
--- @return w,h,col,row
function M.float_geom(frac_w, frac_h, min_w, min_h)
  local cols = (vim.o and vim.o.columns) or 80
  local lines = (vim.o and vim.o.lines) or 24
  local w = math.floor(cols * (frac_w or 0.8))
  local h = math.floor(lines * (frac_h or 0.8))
  w = M.clamp(w, min_w or 40, math.max(min_w or 40, cols - 2))
  h = M.clamp(h, min_h or 10, math.max(min_h or 10, lines - 2))
  local col = math.floor(math.max(0, (cols - w) / 2))
  local row = math.floor(math.max(0, (lines - h) / 2))
  return w, h, col, row
end

--- Hitung jumlah key dict (pairs), bukan # (yang selalu 0 untuk dict).
function M.tbl_count(t)
  local n = 0
  if type(t) ~= "table" then return 0 end
  for _ in pairs(t) do n = n + 1 end
  return n
end

--- Urutan tool stabil (pairs acak, jadi sort eksplisit).
M.TOOL_ORDER = { "adb", "java", "flutter", "git", "gradle" }

function M.sorted_tool_names(results)
  local names = {}
  for _, n in ipairs(M.TOOL_ORDER) do
    if results and results[n] then table.insert(names, n) end
  end
  if results then
    for n in pairs(results) do
      local found = false
      for _, x in ipairs(names) do if x == n then found = true break end end
      if not found then table.insert(names, n) end
    end
  end
  return names
end

--- Project root: git rev-parse --show-toplevel, fallback cwd.
function M.project_root()
  local ok, out = pcall(vim.fn.system, "git rev-parse --show-toplevel 2>/dev/null")
  if ok and out and vim.trim(out) ~= "" then
    local root = vim.trim(out):gsub("\n.*$", "")
    if vim.fn.isdirectory(root) == 1 then return root end
  end
  return vim.fn.getcwd()
end

--- Shell RC files untuk PATH injection persisten (multi-shell).
--- @return list of {rc=path, kind="posix"|"fish"|"powershell"}
function M.shell_rcs()
  if M.OS == "windows" then
    return { { rc = "powershell", kind = "powershell" } }
  end
  local shell = (vim.env.SHELL or ""):lower()
  local home = vim.fn.expand("~")
  if shell:find("fish") then
    return { { rc = home .. "/.config/fish/config.fish", kind = "fish" } }
  end
  if shell:find("zsh") then
    return { { rc = home .. "/.zshrc", kind = "posix" } }
  end
  if shell:find("nu") then
    return { { rc = home .. "/.config/nushell/config.nu", kind = "nushell" } }
  end
  -- default: bash + posix fallback (bashrc + profile)
  return {
    { rc = home .. "/.bashrc", kind = "posix" },
    { rc = home .. "/.profile", kind = "posix" },
  }
end

--- Base dir tools: ~/.anvim/tools ; bin dir: ~/.local/bin (tanpa sudo).
function M.tools_dir()
  return vim.fn.expand("~") .. "/.anvim/tools"
end

function M.local_bin()
  if M.OS == "windows" then
    return vim.fn.expand("~") .. "\\AppData\\Local\\anvim\\bin"
  end
  return vim.fn.expand("~") .. "/.local/bin"
end

--- Close window+buffer aman (tanpa sisa blank window).
function M.close_win_buf(win, buf)
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

return M
