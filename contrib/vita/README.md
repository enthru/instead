# INSTEAD for PS Vita

This directory builds INSTEAD as a PlayStation Vita homebrew package
(`INSTEAD.vpk`) using [VitaSDK](https://vitasdk.org).

## Building

The build needs the VitaSDK toolchain (`arm-vita-eabi-*` and the `vita-*`
packaging tools on `PATH`, `$VITASDK` set) together with the SDL2 stack, LuaJIT,
zlib and freetype vdpm packages. All of that already ships in the official
Docker image, which is the simplest route on macOS/Windows:

```sh
docker run --rm -v "$PWD":/project vitasdk/vitasdk:latest \
       sh /project/contrib/vita/build.sh
```

Output: `build-vita/INSTEAD.vpk`.

If you have a native VitaSDK install, just run the script from the repo root:

```sh
sh contrib/vita/build.sh
```

## Installing

Copy `INSTEAD.vpk` to the Vita and install it with VitaShell (or
molecularShell). It appears on the LiveArea as **INSTEAD** (title id
`INST00001`).

## Layout on the device

- Read-only data (the STEAD engine, themes, language files, the bundled
  tutorial game and the icon) is packed into the vpk and lives under `app0:/`.
- Saves and the config file go to `ux0:data/instead/` on the memory card.
- Extra games can be dropped into `ux0:data/instead/games/<game>/`.

## What was ported

- `contrib/vita/build.sh` — compile + link + `.vpk` packaging (no CMake; the
  desktop CMake build carries a lot of GTK/systemwide baggage that does not
  apply here).
- LuaJIT is used (it is the only Lua in the vdpm repo); it runs in interpreter
  mode on the Vita.
- Platform tweaks are guarded by `__vita__`:
  - `src/unix.c` — app data / save / tmp / config paths point at
    `ux0:data/instead` instead of a Unix `$HOME` (`getpwuid` does not exist in
    newlib).
  - `src/main.c` — `chdir("app0:/")` at startup so the relative data paths
    resolve against the vpk root.
  - `src/instead/util.c` — `is_absolute_path()` recognises Vita drive-prefixed
    paths (`app0:/`, `ux0:...`); the symlink branch of the `realpath()`
    reimplementation is disabled (no `readlink`/`lstat` on Vita).

## Status / known limitations

The package builds and links cleanly, but has **not been verified on real
hardware or Vita3K** yet. Expect to iterate on:

- Input: the front touchscreen maps to the SDL mouse, which is enough to click
  links, but there is no on-screen (IME) keyboard or gamepad mapping yet, so
  games needing text input or comfortable navigation are not playable.
- Rendering scale/DPI for the 960×544 screen (the `mobile`/`wide` themes are the
  likely candidates for the default).
- A proper LiveArea (background/startup image) is not included — only `icon0.png`.
