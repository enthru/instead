![Build status](https://github.com/instead-hub/instead/actions/workflows/CI.yml/badge.svg)

# INSTEAD

This program is covered by the terms of the MIT license.

Check the [COPYING](COPYING) file for license.

Check the [INSTALL](INSTALL) file for install instructions.

## Web resources

- [Homepage](https://instead-hub.github.io)
- [Code](https://github.com/instead-hub/instead)
- [Community](https://instead-games.ru)
- [Documentation](https://instead-hub.github.io/#doc)

## Install games

To run games you may:

- Unzip game archive into ~/.instead/games/;
- Or run zip-packed game: $ instead <game.zip>;
- Or press [f4] to open file dialog (build with gtk2/gtk3 only).

## Building a macOS app bundle

This fork adds tooling to build a self-contained `INSTEAD.app`:

```sh
make app
```

This produces a signed, self-contained `build/INSTEAD.app` (CMake standalone
build + icon generation + dependency bundling via `dylibbundler`). See
[macosx/README.md](macosx/README.md) for details and options.

Verified on **macOS Tahoe (26)**, **arm64** (Apple Silicon), building against
Homebrew's `sdl2` (sdl2-compat over SDL3), `luajit`, `sdl2_image`, `sdl2_mixer`
and `sdl2_ttf`. Includes macOS fixes for Retina HighDPI rendering (sharp, not
oversized) and the stray system cursor.

## Contacts

- Join the irc channel #instead on spline-online.ru;
- Check the [AUTHORS](AUTHORS) file.
