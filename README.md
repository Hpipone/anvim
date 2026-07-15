# anvim

**Android / Flutter Development Toolkit untuk Neovim**  
TUI dashboard floating — alternatif ringan Android Studio. Terinspirasi lazygit.

> **Versi 0.2.0** — Status: Beta

---

## Fitur

| Fitur | Status |
|-------|--------|
| **Dashboard** — floating window TUI navigasi task, device, status tool | ✅ Stabil |
| **System Check** — deteksi ADB, Java, Flutter, Git, Gradle + auto-download | ✅ Stabil |
| **Tool Installation** — download → extract → deploy (mv /usr/bin/ / sudo / PATH fallback) | ✅ Stabil |
| **Task Runner** — run, clean, build APK via background job (non-blocking) | ✅ Stabil |
| **Logcat Viewer** — live `adb logcat`, filter level (V/D/I/W/E/F), riwayathistory | ✅ Stabil |
| **Device Management** — detect & select ADB device | ✅ Stabil |
| **Project Detection** — auto-detect Flutter (pubspec.yaml) / Android (build.gradle) | ✅ Stabil |
| **Unit Tests** — 30 test mencakup semua modul inti | ✅ Stabil |

---

## Perbaikan yang Dilakukan (v0.1.2 → v0.2.0)

### Bug Fixes

- [x] Dashboard centering — teks multi-byte tidak rata tengah
- [x] Blank buffer saat cancel install
- [x] Progress bar tidak realtime (Google CDN blokir HEAD Content-Length)
- [x] mv ke `/usr/bin/` gagal silent — 3-level fallback (mv → sudo mv → PATH injection)
- [x] Tool tidak bisa dipakai di terminal luar — persistent PATH ke shell RC
- [x] Chain install berhenti setelah tool pertama
- [x] Window floating menumpuk tiap close/open
- [x] `get_total_size` & `deploy_binary` global nil error (missing `M.` prefix)
- [x] `adb logcat -v color` invalid format — ganti ke `-v time`
- [x] Cancel install tidak kill background job — `jobstop()` di ESC
- [x] `vim.wait()` blocking UI — ganti `vim.defer_fn`
- [x] Broken Lua pattern di `inject_path_to_rc` — dead code (grep -F fixed string)

### Improvements

- **Extract installation logic** — modul `installation.lua` terpisah
- **Rename help_check → system_check** — "Check System Tools" human-readable
- **Dashboard layout** — border single, padding vertikal, indeks navigation
- **Logcat flow** — history preservasi, reopen dashboard saat close
- **Deploy 3-attempt** — `mv` → `sudo mv` → PATH injection ke shell RC
- **30 unit tests** — mock `vim.*` API, headless Neovim test runner
- **System check floating window** — output ke buffer, bukan `print()`
- **Deprecated API cleanup** — `vim.loop` → `vim.uv`, keymap modern API, buf_set_option → `vim.bo`
- **Health deduplicate** — dashboard pake system_check langsung
- **Task runner streaming** — `stdout_buffered = false`

---

## TODO (Roadmap)

- Belum ada. Semua item selesai dikerjakan.

---

## Syarat

- **Neovim >= 0.9.0**
- **ADB** — untuk Android Debug Bridge
- **Java** — untuk Gradle (Android project)
- **Flutter** — untuk Flutter project (opsional)
- **Git** — untuk version control info

Cek semua tool: `:AnvimCheck`

---

## Install

### lazy.nvim

```lua
return {
  "Hpipone/anvim",
  opts = {},
}
```

Custom config:

```lua
return {
  "Hpipone/anvim",
  opts = {
    dashboard = {
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
    health_check = {
      auto = true,
      tools = { "adb", "java", "git", "flutter", "gradle" },
    },
    logcat = {
      max_lines = 5000,
      filter_default = "I",
    },
  },
}
```

### packer.nvim

```lua
use {
  "Hpipone/anvim",
  config = function()
    require("anvim").setup({})
  end,
}
```

---

## Cara Pakai

### 1. Cek System — `:AnvimCheck`

Pertama kali jalanin `:AnvimCheck`. Ini bakal:

1. Deteksi OS (Linux/macOS/Windows)
2. Cari tool: ADB, Java, Flutter, Git, Gradle
3. Tampilkan laporan lengkap
4. Tool yang bisa didownload otomatis — ketik angka, enter, dia download + extract sendiri

Contoh:

```
╭───── anvim System Check ─────────────────────────────╮
│ OS: LINUX    Arch: x86_64                             │
│ ✓ ADB       /usr/bin/adb                              │
│ ✗ Flutter   tidak ditemukan                           │
│ ✓ Git       /usr/bin/git                              │
├───────────────────────────────────────────────────────┤
│ ⚠  1 tool(s) perlu install                            │
╰───────────────────────────────────────────────────────╯
```

Hasil download di `~/.anvim/tools/<nama_tool>/`.

### 2. Buka Dashboard — `:Anvim` atau `<leader>ad`

Dashboard floating window. Navigasi:

| Tombol | Fungsi |
|--------|--------|
| `j` / `Down` | Navigasi bawah |
| `k` / `Up` | Navigasi atas |
| `Enter` | Pilih item |
| `q` / `Esc` | Tutup dashboard |
| `c` | Cek system tools (AnvimCheck) |
| `r` | Run app |
| `l` | Buka logcat |

Item di dashboard:

- **▶ Run App** — build + install ke device
- **■ Show Logcat** — buka logcat viewer
- **◐ Clean Project** — bersihin build artifacts
- **◆ Build APK** — bikin APK doang
- **↻ Refresh Devices** — refresh daftar device ADB
- **⚡ Check System Tools** — lari ke `:AnvimCheck`

Device terdeteksi otomatis muncul di dashboard. Pilih → Enter jadi device aktif.

### 3. Logcat — dari dashboard atau `:AnvimLogcat`

Live `adb logcat` di buffer terpisah. Riwayat tetap tersimpan meskipun ditutup.

| Tombol | Fungsi |
|--------|--------|
| `V` | Filter VERBOSE |
| `D` | Filter DEBUG |
| `I` | Filter INFO |
| `W` | Filter WARN |
| `E` | Filter ERROR |
| `F` | Filter FATAL |
| `/` | Cari teks di log |
| `q` / `Esc` | Tutup (kembali ke dashboard) |

### 4. Device Management

Device terdeteksi muncul otomatis di dashboard. Pilih device → Enter → device aktif. Semua task (Run, Build) pakai device ini.

---

## Commands

| Command | Fungsi |
|---------|--------|
| `:Anvim` | Buka dashboard |
| `:AnvimCheck` | Cek system + download tool |
| `:AnvimLogcat` | Buka logcat viewer |
| `:AnvimRun` | Run app langsung |

---

## Keymaps Default

| Tombol | Fungsi |
|--------|--------|
| `<leader>ad` | Buka dashboard |
| `<leader>al` | Buka logcat |

Nonaktifkan: `vim.g.anvim_no_default_keymaps = true`

---

## Lisensi

MIT
