#!/bin/sh
#
# make_app.sh - build a self-contained INSTEAD.app bundle for macOS.
#
# Usage:
#   sh macosx/make_app.sh            # build a self-contained, signed .app
#   NO_BUNDLE=1 sh macosx/make_app.sh  # skip dylib bundling (needs Homebrew libs at runtime)
#
# The resulting bundle is placed at build/INSTEAD.app
#
# Requirements (Homebrew):
#   brew install cmake luajit sdl2 sdl2_image sdl2_mixer sdl2_ttf
#   brew install dylibbundler   # optional, for a self-contained bundle
#
set -e

# --- locate project root (this script lives in <root>/macosx/) ----------------
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$ROOT"

BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
APP="$BUILD_DIR/INSTEAD.app"
ICON_SRC="$ROOT/icon/sdl_instead.png"

# --- parse version from CMakeLists.txt ---------------------------------------
VERSION=$(sed -n 's/.*INSTEAD_VERSION "\([^"]*\)".*/\1/p' CMakeLists.txt | head -1)
[ -n "$VERSION" ] || VERSION="0.0.0"

echo ">> Building INSTEAD.app $VERSION"

# --- sanity checks -----------------------------------------------------------
[ "$(uname)" = "Darwin" ] || { echo "!! This script is for macOS only."; exit 1; }
command -v cmake     >/dev/null || { echo "!! cmake not found (brew install cmake)"; exit 1; }
command -v sips      >/dev/null || { echo "!! sips not found (comes with macOS)"; exit 1; }
command -v iconutil  >/dev/null || { echo "!! iconutil not found (comes with macOS)"; exit 1; }

# --- 1. configure & build (standalone, relative data paths) ------------------
mkdir -p "$BUILD_DIR"
( cd "$BUILD_DIR" && cmake "$ROOT" \
    -DWITH_GTK3=0 \
    -DSTANDALONE=1 \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 )
make -C "$BUILD_DIR" -j"$(sysctl -n hw.ncpu)"
# stage stead/themes/games/lang/icon into $BUILD_DIR/standalone
make -C "$BUILD_DIR" install

STAGE="$BUILD_DIR/standalone"
[ -f "$STAGE/sdl-instead" ] || { echo "!! build produced no binary at $STAGE/sdl-instead"; exit 1; }

# --- 2. generate .icns from the PNG icon -------------------------------------
ICONSET="$BUILD_DIR/instead.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for s in 16 32 64 128 256 512; do
    sips -z "$s" "$s" "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null 2>&1
done
cp "$ICONSET/icon_32x32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
iconutil -c icns "$ICONSET" -o "$BUILD_DIR/instead.icns"

# --- 3. assemble the bundle --------------------------------------------------
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$STAGE/sdl-instead" "$APP/Contents/MacOS/instead"
# data goes into Resources: macosx_init() chdir's here at startup (see src/main.c)
cp -R "$STAGE/stead" "$STAGE/themes" "$STAGE/games" "$STAGE/lang" "$STAGE/icon" \
      "$APP/Contents/Resources/"
cp "$BUILD_DIR/instead.icns" "$APP/Contents/Resources/instead.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>INSTEAD</string>
	<key>CFBundleDisplayName</key>
	<string>INSTEAD</string>
	<key>CFBundleIdentifier</key>
	<string>org.instead-hub.instead</string>
	<key>CFBundleVersion</key>
	<string>$VERSION</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleExecutable</key>
	<string>instead</string>
	<key>CFBundleIconFile</key>
	<string>instead.icns</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSMinimumSystemVersion</key>
	<string>10.13</string>
	<key>NSHumanReadableCopyright</key>
	<string>MIT License. INSTEAD interpreter.</string>
</dict>
</plist>
PLIST

# --- 4. make self-contained (bundle dylibs) ----------------------------------
if [ -z "$NO_BUNDLE" ] && command -v dylibbundler >/dev/null; then
    echo ">> Bundling dependent dylibs with dylibbundler"
    ( cd "$APP/Contents" && dylibbundler -od -b \
        -x ./MacOS/instead \
        -d ./Frameworks/ \
        -p @executable_path/../Frameworks/ )

    # Homebrew's "sdl2" is nowadays sdl2-compat: a shim that dlopen's SDL3 at
    # runtime (e.g. @loader_path/libSDL3.dylib). dylibbundler cannot see dlopen'd
    # libraries, so bundle SDL3 next to libSDL2 by hand, otherwise the app fails
    # with "failed to load sdl library" outside the build environment.
    COMPAT="$APP/Contents/Frameworks/libSDL2-2.0.0.dylib"
    if [ -f "$COMPAT" ] && strings "$COMPAT" 2>/dev/null | grep -q 'libSDL3'; then
        SDL3=""
        for p in "$(brew --prefix sdl3 2>/dev/null)/lib" /opt/homebrew/lib /usr/local/lib; do
            [ -e "$p/libSDL3.dylib" ] && { SDL3="$p/libSDL3.dylib"; break; }
        done
        if [ -n "$SDL3" ]; then
            echo ">> Bundling SDL3 (dlopen'd by sdl2-compat)"
            cp "$SDL3" "$APP/Contents/Frameworks/libSDL3.dylib"   # cp follows the symlink
            chmod +w "$APP/Contents/Frameworks/libSDL3.dylib"
            install_name_tool -id @loader_path/libSDL3.dylib \
                "$APP/Contents/Frameworks/libSDL3.dylib" 2>/dev/null || true
            # pull in SDL3's own non-system deps too (usually none)
            ( cd "$APP/Contents" && dylibbundler -of -b \
                -x ./Frameworks/libSDL3.dylib \
                -d ./Frameworks/ \
                -p @loader_path/ >/dev/null 2>&1 ) || true
        else
            echo "!! sdl2-compat detected but libSDL3.dylib not found;"
            echo "   install it with: brew install sdl3"
        fi
    fi
elif [ -z "$NO_BUNDLE" ]; then
    echo "!! dylibbundler not found: bundle will rely on Homebrew libs at /opt/homebrew."
    echo "   Install it (brew install dylibbundler) for a portable .app, or set NO_BUNDLE=1."
fi

# --- 5. ad-hoc sign ----------------------------------------------------------
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
    echo "!! codesign failed (bundle still usable locally)"

echo ""
echo ">> Done: $APP"
du -sh "$APP" 2>/dev/null || true
echo "   Run it:   open \"$APP\""
