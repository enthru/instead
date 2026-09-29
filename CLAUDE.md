# INSTEAD (fork)

INSTEAD is an interpreter for text/graphic adventure games (interactive fiction),
written in C with an embedded Lua (LuaJIT) engine and SDL2. This is a personal
fork of `instead-hub/instead` (remote `upstream`) that adds a **macOS app bundle**
build and a **PS Vita** port. Direct push to `master` on `origin` (this fork).

## Layout

- `src/` — the interpreter. Key files: `main.c` (entry, arg/config parsing),
  `game.c` (game loop, scene rendering, cursor), `graphics.c` (SDL2 render
  layer), `input.c` (keyboard/mouse/touch/gamepad), `themes.c`, `menu.c`,
  `unix.c`/`windows.c`/`macosx.m` (platform paths), `instead/` (Lua engine glue).
- `stead/`, `themes/`, `lang/`, `games/` — runtime data bundled with the app.
- `contrib/vita/` — PS Vita build (`build.sh`, `icon0.png`, `README.md`).
- `macosx/` — macOS app bundle tooling.

## Building

- Desktop (CMake): see `INSTALL`. Data-path modes: SYSTEMWIDE / STANDALONE / dev.
- macOS app bundle: `make app` → `build/INSTEAD.app` (see `macosx/README.md`).
- **PS Vita: `make vita`** → `build-vita/INSTEAD.vpk`. If no native VitaSDK is on
  `PATH`, `contrib/vita/build.sh` transparently builds inside the
  `vitasdk/vitasdk` Docker image (so only Docker is needed on macOS). The Vita
  build does **not** use CMake — the desktop CMake carries GTK/systemwide baggage
  that does not apply.

## PS Vita port — nuances (all C guarded by `#ifdef __vita__`)

Toolchain: VitaSDK via Docker. Uses LuaJIT (only Lua in vdpm; interpreter mode on
Vita), SDL2 stack, zlib, freetype. GTK/HarfBuzz/iconv off.

**Data layout:** read-only data is bundled in the vpk at `app0:/` (paths compiled
relative: `stead/`, `themes/`, …; `main.c` does `chdir("app0:/")` at startup).
Saves/config go to `ux0:data/instead/` (`unix.c` — newlib has no `getpwuid`).
`instead/util.c` `is_absolute_path()` recognises drive-prefixed paths
(`app0:/`, `ux0:...`); the `readlink`/`lstat` symlink branch of `getrealpath()`
is disabled (not in newlib).

**Icon:** `contrib/vita/icon0.png` MUST be an 8-bit palette PNG (run through
`pngquant`). A plain RGBA icon makes the installer fail with `0x8010113D`.

**Rendering is the performance-critical part.** INSTEAD composites the scene in a
software surface, then uploads it to a streaming SDL texture and presents. On
vitaGL, `SDL_UpdateTexture` re-converts the *whole* texture (~90ms) regardless of
the dirty sub-rect — so a naive port runs at ~8 fps whenever anything redraws.
Fixes (in `graphics.c`/`game.c`):
- The cursor is a **GPU overlay** (`gfx_render_cursor()` in `SDL_Flip`), not
  composited into the software surface. A cursor-only move sets `cursor_dirty`
  and just does RenderCopy + present — **no** texture upload. `game_cursor()` on
  Vita only tracks visibility + calls `gfx_cursor_dirty()`.
- `game_cycle()` skips the blanket `gfx_flip()` (full-screen dirty) for ordinary
  frames, so scene changes upload only their changed region.
- Scene **fade** reuses the resident `SDL_VideoTexture` as the background instead
  of uploading a second full-screen texture (`gfx_change_screen`/`update_gfx`).
- Present is vsync-paced (`SDL_RENDERER_PRESENTVSYNC`).
Net: cursor motion ~8 fps → ~60 fps. Takeaway: **never upload the full texture on
a per-frame path**; only on real scene changes.

**Input:** front touchscreen → mouse (`input.c` `touch_mouse_event`, scaled
viewport-aware); the **rear** touchpad is ignored (only `SDL_GetTouchDevice(0)`).
Analog stick drives the pointer via a timer: float quadratic response with
sub-pixel accumulation, clamped to the screen (Vita warp has no corrective
event), vertical damped by aspect ratio. `MOUSE_SHIFT_MAX` tunes speed.

## Testing on device

VitaSDK/hardware only (not runnable on the host). Install `INSTEAD.vpk` with
VitaShell (needs HENkaku/enso). Dev loop used here: VitaShell FTP —
`curl -T build-vita/INSTEAD.vpk "ftp://<vita-ip>:1337/ux0:/INSTEAD.vpk"` then
reinstall. The Vita FTP sleeps/drops often, so uploads may need a retry once
`SELECT` re-enables it. Vita3K (desktop emulator) shows stdout/stderr and is
useful for logs/FPS diagnostics.

## Commit conventions

Message style: `area: imperative summary` (e.g. `vita: ...`, `graphics: ...`),
taken from `git log`. Do not add Claude/Co-Authored-By trailers.
