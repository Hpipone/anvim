# anvim

Android/Flutter Development Dashboard untuk Neovim.
TUI dashboard didalam Neovim — alternatif ringan Android Studio. Terinspirasi lazygit.

note: this repo still in beta version

## Fitur

- **Dashboard** — floating TUI dengan daftar task, device management, status tool
- **Health Check** — deteksi ADB, Java, Flutter, Git, Gradle + bisa download otomatis
- **Task Runner** — run, clean, build APK via background job (gak ngeblock UI)
- **Logcat Viewer** — live `adb logcat` di buffer, filter level (V/D/I/W/E/F)
- **Device Management** — list device ADB, pilih device aktif
- **Project Detection** — auto-detect Flutter (pubspec.yaml) vs Android (build.gradle)

## Syarat

- Neovim >= 0.9.0
- ADB, Java (Android), Flutter (Flutter project) di PATH (cek pake `:AnvimCheck`)

## Cara Install

### lazy.nvim

```lua
return {
  "Hpipone/anvim",
  opts = {},
}
```

Atau kalo mau custom konfigurasi:

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

### packer.nvim / lainnya

```lua
use {
  "Hpipone/anvim",
  config = function()
    require("anvim").setup({})
  end,
}
```

## Cara Pakai

### 1. Cek System — `:AnvimCheck`

Pertama kali, jalanin `:AnvimCheck`. Ini bakal:

1. Deteksi OS kamu (Linux/macOS/Windows)
2. Cari tool seperti ADB, Java, Flutter, Git, Gradle
3. Tampilin laporan siapa yang ada dan siapa yang missing
4. Kalo ada tool yang missing dan bisa didownload otomatis, kamu tinggal ketik angka trus enter — dia download + extract sendiri

Contoh laporan:

```
╭───── anvim System Check ─────────────────────────────╮
│ OS: LINUX    Arch: x86_64                             │
│ ✓ ADB       /usr/bin/adb                              │
│ ✗ Flutter   tidak ditemukan                           │
│ ✓ Git       /usr/bin/git                              │
├───────────────────────────────────────────────────────┤
│ ⚠️  1 tool belum terinstall                           │
╰───────────────────────────────────────────────────────╯
```

Hasil download disimpen di `~/.anvim/tools/<nama_tool>/`.

### 2. Buka Dashboard — `:Anvim` atau `<leader>ad`

Dashboard floating window. Navigasi pake `j`/`k`, enter buat milih.

Di dashboard ada:
- **Run App** — build + install ke device
- **Show Logcat** — buka logcat viewer
- **Clean Project** — bersihin build artifacts
- **Build APK** — bikin APK doang tanpa install
- **List Devices** — refresh daftar device ADB
- **Check System Health** — lari ke `:AnvimCheck`

Kalo ada device connected (cek `adb devices`), muncul di dashboard — tinggal pilih buat jadi device aktif.

### 3. Logcat — `:AnvimLogcat` atau dari dashboard

Live logcat di buffer terpisah:

| Tombol | Fungsi |
|--------|--------|
| `V` | Filter VERBOSE |
| `D` | Filter DEBUG |
| `I` | Filter INFO |
| `W` | Filter WARN |
| `E` | Filter ERROR |
| `F` | Filter FATAL |
| `/` | Cari teks di log |
| `q` / `Esc` | Tutup |

### 4. Device Management

Dari dashboard, device yang terdeteksi muncul otomatis. Pilih device → `Enter` → device itu jadi aktif. Semua task (Run, Build) akan pake device ini.

## Commands

| Command | Fungsi |
|---------|--------|
| `:Anvim` | Buka dashboard |
| `:AnvimCheck` | Cek system + download tool kalo perlu |
| `:AnvimLogcat` | Buka logcat viewer |

## Keymaps Default

| Tombol | Fungsi |
|--------|--------|
| `<leader>ad` | Buka dashboard |
| `<leader>al` | Buka logcat |

Nonaktifin keymap default: `vim.g.anvim_no_default_keymaps = true`

## License

MIT
