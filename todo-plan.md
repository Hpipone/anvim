# anvim long-term plan

> Hasil grilling R1–R3. Fase 1 = refaktor v0.3.0 (sudah dieksekusi + commit master).
> Fase 2 = emulator manager (diekseskusi sekarang).

## Fase 1 — Refaktor v0.3.0 (DONE)
- [x] `util.lua` single-source (OS/ARCH/shellescape/clamp/float_geom/project_root)
- [x] `health.lua` jadi shim → `system_check.lua` single-source + version
- [x] `config` single-source (dashboard/logcat/tasks/install) + `init` leader fix
- [x] Install no-sudo `~/.local/bin` + shellescape + sha256 best-effort + timer close + cancel fix
- [x] Dashboard clamp + skip header + rebuild + rounded dari config (v0.3.0)
- [x] Devices multi-device `-s` + unauthorized/offline + model dash/dot + full id
- [x] Tasks timeout + git-root cwd + split+quickfix + `-s/-d` + stop()
- [x] Logcat `*:LEVEL` benar + `schedule_wrap` + trim history + `no_dashboard_on_close`
- [x] Tests 58 pass (11 suites) + docs v0.3.0

## Fase 2 — Emulator manager (DONE)
- [x] `emulator -list-avds` listing + `find_binary` (PATH/ANDROID_HOME/SDK default paths)
- [x] Launch emulator (`-avd`, cold-boot/quick/wipe-data) via dashboard + `:AnvimEmulator` + key `e`
- [x] Kill emulator (`adb -s <id> emu kill`) via dashboard + `:AnvimEmulatorKill`
- [x] Auto-select emulator baru (poll adb 60s) + boot wait `sys.boot_completed` + timeout config
- [x] Dashboard section Emulators (running/stopped) — pilih running = set active, pilih stopped = launch
- [x] Tests: parse, find_binary, build cmd, boot parse, running_map, kill/launch gagal (68 pass total)

## Fase 3 — Developer experience (DONE, v0.4.0)
- [x] System check rombak: UI selectable keyboard-driven (Enter/i/q), version parse + minimum (Java 17, Gradle 8), emulator opsional, URL Flutter 3.47.0 + Gradle 9.7.1 (macOS ARM split)
- [x] LSP integration: diagnostics count (E/W) di dashboard, filter project root
- [x] Test integration: task `test` (`flutter test` / `gradlew test`) + item dashboard + key `t` + `:AnvimTest`
- [x] Theming: `theme.lua` (`AnvimTitle/Header/Selected/Ok/Warn/Error/Hint`) dipakai dashboard + system check
- [x] Extension API: `tasks.custom` + item ★ + `:AnvimCustom` + `tasks.run_custom`
- [x] `health_check.auto`: warning missing/outdated saat dashboard dibuka
- [x] Active device persisten (`~/.anvim/active_device`, restore + clear)
- [x] Tests 84 pass (13 suites)

## Fase 4 — Pre-release (DONE, v1.0.0)
- [x] Dashboard cursor lock vertikal (h/l/arrows Nop + CursorMoved snap, gg/G)
- [x] Install window diperbesar (0.75 fraksi, min 70x26) + queue stacking bug fix
- [x] ANDROID_HOME doctor (`:AnvimDoctor`, env issues di system check)
- [x] `gradlew` auto `chmod +x` + fallback gradle
- [x] `flutter devices` section di dashboard (flutter.lua)
- [x] Logcat save (`:AnvimLogcatSave`, key `S`), tag filter (key `T`), copy line (`yy`)
- [x] Rerun last task (`:AnvimRerun`, key `R`)
- [x] Statusline/lualine component (`statusline.lua`)
- [x] Help tags (`doc/tags`, `:AnvimHelp`)
- [x] CI (GitHub Actions matrix linux/mac/win + stylua check) + `.stylua.toml`
- [x] README English ringkas + docs sinkron
- [x] Tests 97 pass (15 suites) → release v1.0.0
## Fase 5 — Canonical `~/.local/bin` detection (DONE, v1.1.0)
- [x] Symlink deploy (`ln -sfn`, fallback copy; Windows copy) — tools-dir tetap sumber truth
- [x] PATH session hanya `bin_dir`; `find_tool` prioritas `bin_dir` → PATH → SDK → ANDROID_HOME → folder custom
- [x] Deteksi folder custom: `detect.extra_dirs` + bawaan `~/Downloads` `~/Documents` (depth-limited, cached)
- [x] `M.repair()` di `:AnvimCheck`: buang tools-dir dari PATH + symlink hilang
- [x] Windows `.bat` (flutter/gradle), `;` separator; emulator kenal `local/bin`
- [x] Gradle `ANDROID_SERIAL`, anti-double-`on_done` (job gen), BufWipeout anti-stuck
- [x] Tests 106 pass

## Fase 6 — scrcpy (DONE, v1.2.0)
- [x] TOOLS scrcpy v4.1 (linux x64/macos arm+intel/win64, `no_deploy`, SHA256SUMS per-file, ARM64 fallback manual)
- [x] `scrcpy.lua`: find tools-dir, flags full-custom (size/bitrate/audio/record), launch/stop per-device
- [x] Dashboard section Scrcpy gantikan Emulator (toggle `replace_emulator`), key `m`, `:AnvimScrcpy[KILL]`
- [x] Dashboard instant open: fase cepat + susulan async, cache flutter/emulator, hint loading
- [x] Scrcpy discoverability: optional-installable buka UI check, hint dashboard, pick fallback ke check
- [x] Tests 121 pass (17 suites)

## Fase 7 — unified visibility + npm + deferred search (DONE, v1.3.0)
- [x] Emu+scrcpy hide total tanpa device adb, unhide saat ada; install tidak wajib
- [x] Project node: `package.json` scripts (dev/build/test/clean), label Run/Build (npm), `do_run` cek npm
- [x] TOOLS node opsional (min 18), dicek saat project node
- [x] Deep search (`find` folder custom) hanya pasca-dashboard/saat check (`deep=false` fase cepat)
- [x] Tests 126 pass (17 suites)

## Fase 8 — tech-debt cleanup (DONE, v1.3.1)
- [x] Statusline cache + invalidate DirChanged/BufEnter
- [x] Flutter namespace: validasi adb id ke flutter.list, warn + fallback
- [x] Emulator timer handles + cancel (relaunch/kill)
- [x] Version single-source (dashboard ← config)
- [x] AnvimRun guard unknown; do_rerun jujur; rerun snapshot root
- [x] Logcat auto-recover + close_win unification
- [x] Monorepo walk-up (marker terdekat cwd → git root)
- [x] Tests 136 pass (17 suites)

## Fase 9 — scoped alerts + override + English (DONE, v1.4.0)
- [x] Selection identity: rebuild tidak geser highlight; nav bounded (no wrap)
- [x] required_tools per tipe (node tak ditagih flutter); health_check.tools=nil = auto
- [x] Override: setup({project={type}}) + .anvim.json; nearest-marker menang
- [x] Alerts English konsisten
- [x] Tests 140 pass (17 suites)


## Fase 10 — no scan on dashboard open (DONE, v1.4.0)
- [x] Dashboard tidak panggil check_all (pakai last_results cache + hint press c)
- [x] Hapus auto-warn + health_check.auto dari defaults (scan hanya user-trigger)
- [x] Tests 142 pass (17 suites)

## Fase 11 — minimal highlight + adb console (DONE, v1.4.1)
- [x] Highlight hanya baris info + cursor (cursorline, tanpa Selected)
- [x] Rename mirror → scrcpy (user-facing)
- [x] Konsol adb `:AnvimAdb` + key `:`: toggle preset (connect IP:port validasi, shell, custom), -s otomatis
- [x] Tests 147 pass (17 suites)

## Fase 12 — cursor-only, adb console, closable output (DONE, v1.5.0)
- [x] Hapus semua extmark highlight dashboard (cursor + cursorline saja)
- [x] Rename mirror → scrcpy (user-facing)
- [x] Konsol adb `:` / `:AnvimAdb`: toggle preset, connect IP:port validasi, -s otomatis, auto-select device baru
- [x] Task window: q/Esc + `:AnvimTaskClose` (buffer dipertahankan)
- [x] Tests 149 pass (17 suites)

## Fase 13 — zero highlight, pair, front output (DONE, v1.6.0)
- [x] Hapus highlight system_check juga (cursor only di semua UI)
- [x] Task output zindex depan + q/Esc tutup → kembali dashboard
- [x] adb pair + input kode (chansend), preset toggle, hapus log done
- [x] Tests 155 pass (17 suites)
