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

## PS Vita

This fork also runs on the PlayStation Vita. To build the package yourself, see
[contrib/vita/README.md](contrib/vita/README.md).

### Installing INSTEAD

You need a Vita with HENkaku/Ensō and [VitaShell](https://github.com/TheOfficialFloW/VitaShell).

1. Download `INSTEAD.vpk` from the
   [latest release](https://github.com/enthru/instead/releases/latest).
2. Copy it to the Vita (see [Connecting to the Vita](#connecting-to-the-vita)),
   for example to `ux0:/`.
3. In VitaShell, select the file and press X to install it.

### Adding games

Games live in `ux0:data/instead/games/`. INSTEAD does not create this folder
until it unpacks a game, so create it the first time: in VitaShell, open
`ux0:data/instead/`, press Triangle and choose *New folder*. If
`ux0:data/instead/` does not exist either, start INSTEAD once or create it the
same way.

Then copy each game there in one of these forms:

- **A `.zip` archive** (`games/mygame.zip`). It appears in the game list under
  the name of the file. It is unpacked the first time you select it, and the
  archive is then deleted.
- **An unpacked folder** (`games/mygame/`) with `main3.lua` or `main.lua`
  directly inside it.
- **An `.idf` file** (`games/mygame.idf`).

A `.zip` must hold everything inside a single top-level folder:

```text
mygame.zip
└── mygame/
    ├── main3.lua
    └── ...
```

An archive with the files at its root, or with several top-level folders, fails
to unpack. This includes archives made with *Compress* in the macOS Finder,
which add a `__MACOSX` folder. On macOS, use `zip -r mygame.zip mygame` instead.

The game list is only read at startup, so restart INSTEAD after copying. Press
START to open the menu, then pick the game from the game list. To remove a game
you added, press the `[X]` next to it in the list.

### Connecting to the Vita

**FTP:** in VitaShell, press SELECT to start the FTP server. It shows the
address to connect to, and any FTP client will work. With `curl`:

```sh
curl -T mygame.zip "ftp://<vita-ip>:1337/ux0:/data/instead/games/mygame.zip"
```

The connection can drop when the Vita goes to sleep. If it does, press SELECT
again and retry the upload.

**USB:** press START in VitaShell and set the SELECT button to USB, then connect
the cable and press SELECT. The memory card mounts as a disk, and the games
folder is `data/instead/games/` on it. Eject the disk before you disconnect.

## Contacts

- Join the irc channel #instead on spline-online.ru;
- Check the [AUTHORS](AUTHORS) file.
