-- anvim: installation — download, verify sha256, extract, deploy (no-sudo)
-- Model aman: binary tetap di ~/.anvim/tools/<name>/, copy/symlink ke ~/.local/bin,
-- PATH injection persisten multi-shell. Tanpa sudo, tanpa mv ke /usr/bin.

local M = {}
M.install_active = false
M.install_cancelled = false
M.phase = ""
M.job_id = nil

local alert = require("anvim.status-alert")
local util = require("anvim.util")
local OS = util.OS

-- helpers
local function fmt_size(bytes)
  bytes = bytes or 0
  if bytes < 1024 then return string.format("%.0f B", bytes) end
  if bytes < 1024 * 1024 then return string.format("%.1f KB", bytes / 1024) end
  if bytes < 1024 * 1024 * 1024 then return string.format("%.1f MB", bytes / (1024 * 1024)) end
  return string.format("%.2f GB", bytes / (1024 * 1024 * 1024))
end

local function fmt_speed(bps)
  bps = bps or 0
  if bps < 1024 then return string.format("%.0f B/s", bps) end
  if bps < 1024 * 1024 then return string.format("%.1f KB/s", bps / 1024) end
  return string.format("%.1f MB/s", bps / (1024 * 1024))
end

local BAR_W = 30

local function render_progress(buf, phase, downloaded, total, speed, logs)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local lines = { "", "  " .. (phase or "") , "" }
  if total > 0 then
    local pct = math.min(100, downloaded / total * 100)
    local filled = math.floor(pct / 100 * BAR_W)
    local bar = "[" .. string.rep("■", filled) .. string.rep("□", BAR_W - filled) .. "]"
    local eta = speed > 0 and ((total - downloaded) / speed) or 0
    local eta_s = eta > 0 and string.format("%02d:%02d:%02d", math.floor(eta / 3600), math.floor((eta % 3600) / 60), math.floor(eta % 60)) or "--:--:--"
    table.insert(lines, "  " .. bar .. "  " .. string.format("%5.1f%%", pct))
    table.insert(lines, "  Downloaded: " .. fmt_size(downloaded) .. " / " .. fmt_size(total) .. "  Speed: " .. fmt_speed(speed) .. "  ETA: " .. eta_s)
  else
    local spinners = { "|", "/", "-", "\\" }
    local s = spinners[math.floor(vim.uv.now() / 200) % 4 + 1] or "|"
    table.insert(lines, "  " .. s .. " Downloading... " .. fmt_size(downloaded))
    table.insert(lines, "  Speed: " .. fmt_speed(speed) .. "    Size: unknown")
  end
  table.insert(lines, "")
  local start = math.max(1, #logs - 20 + 1)
  for i = start, #logs do
    table.insert(lines, "  > " .. logs[i])
  end
  vim.bo[buf].modifiable = true
  pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

function M.get_total_size(url)
  if vim.fn.executable("curl") == 1 then
    local ok, out = pcall(vim.fn.system, "curl -sIkL " .. util.esc(url) .. " 2>/dev/null | grep -i content-length | tail -1")
    if ok and out then
      local len = out:match("(%d+)")
      if len and tonumber(len) > 0 then return tonumber(len) end
    end
  end
  if vim.fn.executable("wget") == 1 then
    local ok, out = pcall(vim.fn.system, "wget --spider --server-response " .. util.esc(url) .. " 2>&1 | grep -i content-length | tail -1")
    if ok and out then
      local len = out:match("(%d+)")
      if len and tonumber(len) > 0 then return tonumber(len) end
    end
  end
  return 0
end

--- Download text file (sha256) via curl, return trimmed string atau nil.
local function fetch_text(url)
  if vim.fn.executable("curl") ~= 1 then return nil end
  local ok, out = pcall(vim.fn.system, "curl -sSL --max-time 30 " .. util.esc(url) .. " 2>/dev/null")
  if not ok or not out or vim.trim(out) == "" then return nil end
  return vim.trim(out)
end

--- Hitung sha256 file lokal via sha256sum / shasum.
local function file_sha256(path)
  local cmd
  if vim.fn.executable("sha256sum") == 1 then
    cmd = "sha256sum " .. util.esc(path) .. " 2>/dev/null | cut -d' ' -f1"
  elseif vim.fn.executable("shasum") == 1 then
    cmd = "shasum -a 256 " .. util.esc(path) .. " 2>/dev/null | cut -d' ' -f1"
  else
    return nil, "no sha256 tool (install coreutils)"
  end
  local ok, out = pcall(vim.fn.system, cmd)
  if not ok or not out then return nil, "sha256 compute failed" end
  local h = vim.trim(out):match("^(%x+)")
  if not h or #h ~= 64 then return nil, "sha256 parse failed" end
  return h:lower(), nil
end

--- Best-effort verify: cek sha256 hanya jika sha256_url tersedia dan
--- checksum bisa diunduh. Tidak pernah memblokir install — hanya warning.
--- Mismatch tetap menggagalkan (file korup / MITM), tapi checksum yang
--- hilang (mis. platform-tools Google tidak publish) hanya warning.
--- Return true agar install lanjut; false hanya saat mismatch terbukti.
function M.verify_sha256(zip_path, dl_info, logs)
  local sha_url = dl_info and dl_info.sha256_url or nil
  if not sha_url then
    table.insert(logs, "⚠ sha256 skipped (no official checksum published) — lanjut install")
    return true
  end
  table.insert(logs, "Verifying sha256...")
  local remote = fetch_text(sha_url)
  if not remote then
    table.insert(logs, "⚠ sha256 download gagal — lanjut tanpa verify: " .. sha_url)
    return true
  end
  local expected = remote:match("(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)"):lower()
  if not expected then
    table.insert(logs, "⚠ sha256 remote tidak valid — lanjut tanpa verify")
    return true
  end
  local actual, err = file_sha256(zip_path)
  if not actual then
    table.insert(logs, "⚠ sha256 lokal gagal (" .. tostring(err) .. ") — lanjut tanpa verify")
    return true
  end
  if actual ~= expected then
    table.insert(logs, "✗ CHECKSUM MISMATCH!")
    table.insert(logs, "  expected: " .. expected)
    table.insert(logs, "  actual:   " .. actual)
    return false
  end
  table.insert(logs, "✓ sha256 verified")
  return true
end

local function open_progress_win(name)
  local buf = vim.api.nvim_create_buf(false, true)
  local w, h, col, row = util.float_geom(0.75, 0.75, 70, 26)
  -- besar agar log terbaca, tapi clamp layar kecil
  w = math.min(100, w)
  h = math.min(34, h)
  col = math.floor(math.max(0, ((vim.o.columns or 80) - w) / 2))
  row = math.floor(math.max(0, ((vim.o.lines or 24) - h) / 2))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = w, height = h,
    col = col, row = row,
    style = "minimal", border = "rounded",
    title = " Install " .. name .. " ", title_pos = "center",
  })
  return buf, win
end

--- Inject PATH persisten multi-shell. Return (ok, log).
local function inject_path_to_rc(bin_dir)
  if OS == "windows" then
    -- setx syntax benar: setx PATH "%PATH%;C:\dir"
    local cmd = "setx PATH \"%PATH%;" .. bin_dir .. "\" 2>&1"
    local ok, out = pcall(vim.fn.system, cmd)
    if ok and out and (out:match("SUCCESS") or out:match("Berhasil")) then
      return true, "✓ PATH set via setx — buka terminal baru"
    end
    return false, "⚠ setx gagal, tambah manual: " .. bin_dir
  end

  local export_posix = 'export PATH="$PATH:' .. bin_dir .. '"'
  local fish_line = "set -gx PATH $PATH " .. bin_dir
  local nu_line = "$env.PATH = ($env.PATH | append '" .. bin_dir .. "')"
  local any_ok = false
  local notes = {}

  for _, e in ipairs(util.shell_rcs()) do
    local line = export_posix
    if e.kind == "fish" then line = fish_line
    elseif e.kind == "nushell" then line = nu_line
    elseif e.kind == "powershell" then line = nil end
    if line then
      local check = ""
      pcall(function()
        check = vim.fn.system("grep -F " .. util.esc(line) .. " " .. util.esc(e.rc) .. " 2>/dev/null")
      end)
      if check and check ~= "" then
        any_ok = true
        table.insert(notes, e.rc .. " ok")
      else
        local wok = pcall(function()
          vim.fn.mkdir(vim.fn.fnamemodify(e.rc, ":h"), "p")
          local f = io.open(vim.fn.expand(e.rc), "a")
          if not f then error("open failed") end
          f:write("\n" .. line .. "\n")
          f:close()
        end)
        if wok then
          any_ok = true
          table.insert(notes, e.rc .. " updated")
        end
      end
    end
  end

  if any_ok then
    return true, "✓ PATH added (" .. table.concat(notes, ", ") .. ") — terminal baru bisa pakai"
  end
  return false, "⚠ Gagal nulis RC, tambah manual: " .. export_posix
end

--- Deploy aman tanpa sudo: copy binary ke ~/.local/bin + PATH injection.
--- Tidak memindahkan file keluar dari tools dir (tidak merusak tool_subdir).
--- Return (success, log_lines)
function M.deploy_binary(bin_path, bin_name, tool_subdir, logs)
  local lines = {}
  if not util.is_safe_bin_name(bin_name) then
    table.insert(lines, "✗ unsafe binary name: " .. tostring(bin_name))
    return false, lines
  end

  local cfg_ok, cfg = pcall(function() return require("anvim.config").get() end)
  local bin_dir = (cfg_ok and cfg and cfg.install and cfg.install.bin_dir) or util.local_bin()
  if OS == "windows" then
    pcall(vim.fn.mkdir, bin_dir, "p")
    table.insert(lines, "Deploy " .. bin_name .. " → " .. bin_dir)
    local ok_cp = pcall(vim.fn.system, "copy " .. util.esc(bin_path) .. " " .. util.esc(bin_dir) .. " 2>&1")
    if vim.fn.executable(bin_name) == 1 or vim.fn.executable(bin_dir .. "\\" .. bin_name) == 1 then
      table.insert(lines, "✓ " .. bin_name .. " ready")
      return true, lines
    end
    local _, log_line = inject_path_to_rc(bin_dir)
    table.insert(lines, "  " .. log_line)
    return false, lines
  end

  pcall(vim.fn.mkdir, bin_dir, "p")
  table.insert(lines, "Deploy " .. bin_name .. " → " .. bin_dir .. " ...")

  -- copy (bukan mv) agar tools dir tetap utuh
  local cp_cmd = "cp -f " .. util.esc(bin_path) .. " " .. util.esc(bin_dir .. "/" .. bin_name) .. " 2>&1"
  pcall(vim.fn.system, cp_cmd)
  pcall(vim.fn.system, "chmod +x " .. util.esc(bin_dir .. "/" .. bin_name) .. " 2>/dev/null")

  -- update PATH session ini
  for _, p in ipairs({ bin_dir, tool_subdir }) do
    if p and p ~= "" and not vim.env.PATH:find(p, 1, true) then
      vim.env.PATH = p .. ":" .. vim.env.PATH
    end
  end

  if vim.fn.executable(bin_name) == 1 or vim.fn.executable(bin_dir .. "/" .. bin_name) == 1 then
    table.insert(lines, "✓ " .. bin_name .. " ready (no sudo)")
    local _, log_line = inject_path_to_rc(bin_dir)
    table.insert(lines, "  " .. log_line)
    return true, lines
  end

  table.insert(lines, "  copy gagal / belum di PATH")
  local _, log_line = inject_path_to_rc(bin_dir)
  table.insert(lines, "  " .. log_line)
  table.insert(lines, "⚠ manual: cp " .. bin_path .. " " .. bin_dir .. "/")
  return false, lines
end

-- install_tool: download → verify sha256 → extract → deploy → verify
function M.install_tool(name, dl_info, label, bin_name, on_done)
  on_done = on_done or function() end
  if not util.is_safe_bin_name(bin_name) then
    alert.error("install", "unsafe binary name: " .. tostring(bin_name))
    on_done(false)
    return
  end
  local cfg_ok, cfg = pcall(function() return require("anvim.config").get() end)
  local base = (cfg_ok and cfg and cfg.install and cfg.install.dir) or util.tools_dir()
  local dest = base .. "/" .. name
  local zip_path = dest .. "/" .. dl_info.file

  if vim.fn.executable(bin_name) == 1 then
    alert.info(label .. " already in PATH, skip")
    on_done(true)
    return
  end

  vim.fn.mkdir(dest, "p")
  local total = M.get_total_size(dl_info.url)
  local logs = {}
  local start_time = vim.uv.now()
  M.install_active = true
  M.install_cancelled = false
  M.phase = "Starting " .. label .. "..."

  local pw_buf, pw_win = open_progress_win(label)
  require("anvim.keymaps.installation").set(pw_buf)

  local last_bytes = 0
  local last_time = start_time
  local speed = 0
  local timer = nil

  local function stop_timer()
    if timer then
      pcall(function() timer:stop() end)
      pcall(function() timer:close() end)
      timer = nil
    end
  end

  local function close_pw()
    stop_timer()
    M.install_active = false
    M.job_id = nil
    util.close_win_buf(pw_win, pw_buf)
    pw_win, pw_buf = nil, nil
  end

  local function fail(msg, done_val)
    table.insert(logs, msg)
    render_progress(pw_buf, M.phase, 0, total, speed, logs)
    stop_timer()
    M.install_active = false
    vim.defer_fn(function() close_pw(); on_done(done_val == true) end, 2000)
  end

  local function redraw()
    local info = vim.uv.fs_stat(zip_path)
    local dl = info and info.size or 0
    render_progress(pw_buf, M.phase, dl, total, speed, logs)
  end

  local ok_t, t = pcall(vim.uv.new_timer)
  if ok_t and t then
    timer = t
    timer:start(0, 200, vim.schedule_wrap(function()
      if not M.install_active then return end
      local info = vim.uv.fs_stat(zip_path)
      local downloaded = info and info.size or 0
      local now = vim.uv.now()
      local dt = (now - last_time) / 1000
      if dt > 0 then
        speed = (speed * 0.7) + ((downloaded - last_bytes) / dt * 0.3)
      end
      last_bytes = downloaded
      last_time = now
      render_progress(pw_buf, M.phase, downloaded, total, speed, logs)
    end))
  end

  -- PHASE 1: download
  M.phase = "Downloading " .. label .. "..."
  local cmd
  if vim.fn.executable("curl") == 1 then
    cmd = { "curl", "-L", "--fail", "-o", zip_path, dl_info.url }
  elseif vim.fn.executable("wget") == 1 then
    cmd = { "wget", "-O", zip_path, dl_info.url }
  else
    fail("ERROR: need curl or wget", false)
    return
  end

  table.insert(logs, "Downloading...")
  redraw()

  M.job_id = vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if not M.install_active then close_pw(); on_done(false); return end

      if code ~= 0 then
        fail("Download failed (exit " .. tostring(code) .. ")", false)
        return
      end

      table.insert(logs, "Download done (" .. fmt_size(total) .. ")")
      redraw()

      -- PHASE 1b: best-effort sha256 verify (mismatch = gagal, hilang = warning)
      if not M.verify_sha256(zip_path, dl_info, logs) then
        redraw()
        fail("Checksum verify gagal — file dihapus agar aman", false)
        pcall(os.remove, zip_path)
        return
      end
      redraw()

      -- PHASE 2: extract
      if M.install_active then
        M.phase = "Extracting " .. label .. "..."
        table.insert(logs, "Extracting...")
        redraw()

        local extract_cmd
        local extract_dir = dest .. "/extracted"
        vim.fn.mkdir(extract_dir, "p")

        if zip_path:match("%.zip$") then
          if vim.fn.executable("unzip") == 1 then
            extract_cmd = { "unzip", "-o", zip_path, "-d", extract_dir }
          end
        elseif zip_path:match("%.tar%.xz$") or zip_path:match("%.tar%.gz$") or zip_path:match("%.tgz$") then
          if vim.fn.executable("tar") == 1 then
            extract_cmd = { "tar", "-xf", zip_path, "-C", extract_dir }
          end
        end

        if not extract_cmd then
          fail("Manual extract: " .. zip_path, false)
          return
        end

        table.insert(logs, "Running: " .. table.concat(extract_cmd, " "))
        redraw()

        M.job_id = vim.fn.jobstart(extract_cmd, {
          on_exit = function(_, ecode)
            if not M.install_active then close_pw(); on_done(false); return end

            if ecode ~= 0 then
              fail("Extract failed (exit " .. tostring(ecode) .. ")", false)
              return
            end

            table.insert(logs, "Extract OK")
            table.insert(logs, "Organizing files...")

            local found = vim.fn.glob(extract_dir .. "/**/" .. bin_name, false, true)
            local rel_path = ""
            if #found > 0 then
              local parent = vim.fn.fnamemodify(found[1], ":h")
              rel_path = parent:sub(#extract_dir + 2)
            end

            if OS == "windows" then
              pcall(vim.fn.system, "move " .. util.esc(extract_dir .. "\\*") .. " " .. util.esc(dest .. "\\"))
            else
              pcall(vim.fn.system, "cp -r " .. util.esc(extract_dir) .. "/* " .. util.esc(dest) .. "/")
            end
            pcall(os.remove, zip_path)
            pcall(vim.fn.system, "rm -rf " .. util.esc(extract_dir))
            table.insert(logs, "Installed at: " .. dest)
            redraw()

            -- PHASE 3: deploy (no-sudo copy ke ~/.local/bin)
            M.phase = "Deploying " .. label .. "..."
            local tool_subdir = dest
            if rel_path and rel_path ~= "" then
              tool_subdir = dest .. "/" .. rel_path
            end

            local bin_path = tool_subdir .. "/" .. bin_name
            local deployed, deploy_logs = M.deploy_binary(bin_path, bin_name, tool_subdir, logs)
            for _, l in ipairs(deploy_logs) do
              table.insert(logs, l)
            end
            redraw()

            -- PHASE 4: verify executable (tanpa sukses palsu)
            M.phase = "Verifying..."
            table.insert(logs, "Verifying...")
            redraw()

            local bin_dir = (cfg_ok and cfg and cfg.install and cfg.install.bin_dir) or util.local_bin()
            for _, p in ipairs({ bin_dir, dest, tool_subdir }) do
              if p and p ~= "" and not vim.env.PATH:find(p, 1, true) then
                vim.env.PATH = p .. ":" .. vim.env.PATH
              end
            end

            local verified = vim.fn.executable(bin_name) == 1
            if verified and deployed then
              table.insert(logs, "✓ " .. label .. " siap dipakai!")
              redraw()
              M.phase = "✓ Install done!"
              stop_timer()
              render_progress(pw_buf, M.phase, total, total, 0, logs)
              M.install_active = false
              vim.defer_fn(function() close_pw(); on_done(true) end, 1500)
            else
              table.insert(logs, "✗ " .. label .. " gagal verifikasi — lihat log di atas")
              redraw()
              stop_timer()
              M.install_active = false
              vim.defer_fn(function() close_pw(); on_done(false) end, 2000)
            end
          end,
        })
      end
    end,
  })
  if M.job_id == nil or M.job_id <= 0 then
    fail("jobstart gagal", false)
  end
end

return M
