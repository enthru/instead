# Building INSTEAD.app for macOS

INSTEAD has no prebuilt macOS application bundle in the source tree, but the
interpreter already supports running from inside a `.app`: on startup
`macosx_init()` (see `src/main.c`) uses `CFBundle` to `chdir` into
`Contents/Resources/`, where the interpreter looks up its data (`stead`,
`themes`, `games`, `lang`) via relative paths. This directory holds the tooling
to assemble that bundle.

## Quick start

```sh
# from the repository root
make app
```

This produces a self-contained, ad-hoc signed **`build/INSTEAD.app`** and prints
its location. Launch it with:

```sh
open build/INSTEAD.app
```

`make app` is a thin wrapper around `macosx/make_app.sh`; you can also run the
script directly.

## Requirements

Install the toolchain and libraries with [Homebrew](https://brew.sh):

```sh
brew install cmake luajit sdl2 sdl2_image sdl2_mixer sdl2_ttf
brew install dylibbundler   # optional, needed for a portable .app
```

`sips` and `iconutil` (used to generate the icon) ship with macOS.

## What the script does

`macosx/make_app.sh` runs the whole pipeline:

1. **Configure & build** with CMake in `STANDALONE` mode, so the interpreter
   uses relative data paths (`stead/`, `themes/`, ...):

   ```sh
   cmake .. -DWITH_GTK3=0 -DSTANDALONE=1 -DCMAKE_POLICY_VERSION_MINIMUM=3.5
   make -j
   make install          # stages data into build/standalone/
   ```

   `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` is required because the project declares
   an old `cmake_minimum_required` that recent CMake refuses without it.
   GTK is disabled — it is a Linux file-dialog dependency and is not needed on
   macOS.

2. **Generate the icon**: rasterizes `icon/sdl_instead.png` into an `.iconset`
   with `sips` and packs it into `instead.icns` with `iconutil`.

3. **Assemble the bundle**:

   ```
   INSTEAD.app/Contents/
     Info.plist          # metadata (id org.instead-hub.instead)
     MacOS/instead       # the interpreter binary
     Resources/          # stead, themes, games, lang, icon, instead.icns
     Frameworks/         # bundled dylibs (see step 4)
   ```

4. **Bundle dylibs** with `dylibbundler`: copies SDL2, LuaJIT and all audio /
   image codecs into `Contents/Frameworks/` and rewrites the load paths to
   `@executable_path/../Frameworks/`, so the app runs on any Mac without
   Homebrew. Skip this step with `NO_BUNDLE=1` (the bundle then depends on the
   Homebrew libraries under `/opt/homebrew`).

   Homebrew's `sdl2` formula is now **sdl2-compat**, a shim that `dlopen`s
   **SDL3** at runtime. `dylibbundler` cannot follow `dlopen`, so the script
   additionally copies `libSDL3.dylib` next to `libSDL2` inside `Frameworks/`
   (resolving `@loader_path/libSDL3.dylib`). Without this the app aborts with
   *"failed to load sdl library"* when launched outside the build environment
   (e.g. by double-clicking in Finder). This needs `brew install sdl3` (pulled
   in automatically as a dependency of `sdl2`).

5. **Ad-hoc code sign** the finished bundle (`codesign --deep --sign -`).

## Options

| Variable    | Effect                                                              |
|-------------|--------------------------------------------------------------------|
| `NO_BUNDLE=1` | Do not bundle dylibs; rely on Homebrew libraries at runtime.      |
| `BUILD_DIR` | Override the build/output directory (default `build/`).            |

Example:

```sh
NO_BUNDLE=1 make app
```

## Distribution notes

- The bundle is **ad-hoc signed** (`TeamIdentifier=not set`). On another Mac,
  Gatekeeper will block it until you right-click → *Open*, or clear the
  quarantine flag:

  ```sh
  xattr -dr com.apple.quarantine INSTEAD.app
  ```

  For public distribution you need a Developer ID signature and notarization.

- The app is built for the **host architecture** only. For a universal binary,
  build separately for `arm64` and `x86_64` and merge the executables and
  dylibs with `lipo`.
