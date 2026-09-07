# anvim

**Android / Flutter Development Toolkit untuk Neovim**  
TUI dashboard floating — alternatif ringan Android Studio. Terinspirasi lazygit.

> **Versi 0.4.0** — Status: Beta (fase 3: DX + system check rombak)

---

## Fitur

| Fitur | Status |
|-------|--------|
| **Dashboard** — floating `0.8x0.8` clamp, skip header nav, refresh devices rebuild | ✅ Stabil |
| **System Check** — UI selectable keyboard-driven, deteksi versi + minimum (Java 17, Gradle 8), Flutter 3.47 / Gradle 9.7.1 | ✅ Stabil |
| **Tool Installation** — download → verify sha256 (best-effort) → extract → copy ke `~/.local/bin` (tanpa sudo) | ✅ Stabil |
| **Task Runner** — run/clean/build/test via background job, timeout, split output + quickfix, `-s/-d` device, custom tasks | ✅ Stabil |
| **Logcat Viewer** — live `adb logcat -v time *:LEVEL`, trim history, `q` kembali ke kode | ✅ Stabil |
| **Device Management** — detect multi-device, warning unauthorized/offline, `-s` diteruskan, active persisten | ✅ Stabil |
| **Dashboard** — theming highlight groups, diagnostics LSP, auto health warning | ✅ Stabil |
| **Emulator Manager** — list AVD, launch (cold/quick/wipe), kill, boot wait + auto-select | ✅ Stabil |
| **Project Detection** — git-root aware, Flutter quotes-strip, Gradle KTS, branch info | ✅ Stabil |
| **Unit Tests** — 84 test (util/config/install/dashboard/system_check/logcat/devices/tasks/project/init/health/emulator/theme) | ✅ Stabil |

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

Lihat `todo-plan.md` untuk long-term plan (emulator manager, LSP, test integration, theming, custom tasks API, version check).

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
      no_dashboard_on_close = true,
    },
    tasks = {
      timeout_ms = 300000,
      custom = {
        { label = "Lint", cmd = { "flutter", "analyze" } },
      },
    },
    emulator = {
      boot_timeout_ms = 120000,
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

1. Deteksi OS (Linux/macOS/Windows) + Arch
2. Cari tool: ADB, Java, Flutter, Git, Gradle (+ Emulator opsional) beserta versinya
3. Tandai versi di bawah minimum (⚠ Java min 17, Gradle min 8)
4. Tampilkan UI selectable: `j/k` navigasi, `Enter` install/pilih, `i` install semua, `q` tutup

Contoh:

```
OS: LINUX  Arch: x86_64
✓ ADB 1.0.41 — /usr/bin/adb
⚠ Java 11.0.2 outdated (min 17) — /usr/bin/java
✗ Flutter not found — Install Flutter SDK dan set PATH.
1 tool(s) need install
```

Hasil download di `~/.anvim/tools/<nama_tool>/`, binary di-copy ke `~/.local/bin/` (tanpa sudo, PATH di-inject ke shell RC).

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
| `t` | Run tests |
| `l` | Buka logcat |
| `x` | Cancel task yang sedang jalan |
| `e` | Launch emulator |

Item di dashboard:

- **▶ Run App** — build + install ke device
- **■ Show Logcat** — buka logcat viewer
- **◐ Clean Project** — bersihin build artifacts
- **◆ Build APK** — bikin APK doang
- **◈ Run Tests** — `flutter test` / `./gradlew test`
- **★ Custom** — task sendiri dari `setup({tasks={custom=...}})`
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
| `q` / `Esc` | Tutup (kembali ke kode) |

### 4. Device Management

Device terdeteksi muncul otomatis di dashboard. Pilih → Enter jadi device aktif (tersimpan di `~/.anvim/active_device`, restore otomatis). Semua task (Run, Build, Test) pakai device ini.

### 5. Emulator Manager

Butuh Android SDK Emulator + minimal 1 AVD (buat via Android Studio → Device Manager).

- Dashboard → section **Emulators**: `○ Nama (stopped)` / `● Nama (emulator-5554)` + `▶ Launch Emulator…` / `■ Kill Emulator…`
- Pilih AVD stopped → Enter langsung launch (cold boot); pilih yang running → jadi device aktif
- Key `e` atau `:AnvimEmulator` → picker AVD + mode (cold boot / wipe data / quick boot)
- `:AnvimEmulatorKill` → matikan emulator yang jalan
- Setelah launch: tunggu `emulator-XXXX` muncul di `adb devices` (60s), auto-select, lalu tunggu `sys.boot_completed` (default 120s, config `emulator.boot_timeout_ms`)

---

## Commands

| Command | Fungsi |
|---------|--------|
| `:Anvim` | Buka dashboard |
| `:AnvimCheck` | Cek system + download tool |
| `:AnvimLogcat` | Buka logcat viewer |
| `:AnvimRun` | Run app langsung |
| `:AnvimTest` | Run project tests |
| `:AnvimCustom` | Run custom task (picker) |
| `:AnvimEmulator` | Launch emulator (picker) |
| `:AnvimEmulatorKill` | Kill emulator yang jalan |

### Custom tasks

```lua
require("anvim").setup({
  tasks = {
    custom = {
      { label = "Lint", cmd = { "flutter", "analyze" } },
      { label = "APK release", cmd = { "flutter", "build", "apk", "--release" } },
    },
  },
})
```

Muncul di dashboard (★) + `:AnvimCustom`.

### Theming

Highlight groups (override sesukamu):

```lua
vim.api.nvim_set_hl(0, "AnvimSelected", { link = "Visual" })
-- AnvimTitle, AnvimHeader, AnvimOk, AnvimWarn, AnvimError, AnvimHint
```

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
