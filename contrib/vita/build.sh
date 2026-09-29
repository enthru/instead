#!/bin/sh
#
# Build INSTEAD as a PS Vita .vpk.
#
# Runs inside the VitaSDK environment (arm-vita-eabi-* + vita-* tools on PATH,
# $VITASDK set). The easiest way from macOS/Windows is the vitasdk Docker image:
#
#   docker run --rm -v "$PWD":/project vitasdk/vitasdk:latest \
#          sh /project/contrib/vita/build.sh
#
# Output: build-vita/INSTEAD.vpk
#
set -e

# Locate project root (this script lives in contrib/vita/).
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
cd "$ROOT"

VERSION=$(grep 'SET(INSTEAD_VERSION' CMakeLists.txt | sed 's/[^0-9.]//g')
[ -n "$VERSION" ] || VERSION=3.5.2

TITLE="INSTEAD"
TITLEID="INST00001"

BUILD=build-vita
OBJ="$BUILD/obj"
mkdir -p "$OBJ"

PKG=arm-vita-eabi-pkg-config
STACK="sdl2 SDL2_image SDL2_mixer SDL2_ttf luajit zlib freetype2"
CFLAGS=$($PKG --cflags $STACK)
LIBS=$($PKG --libs $STACK)
# Extra stubs pulled in by vitaGL's runtime shader compiler (vitashark).
EXTRA_LIBS="-lSceShaccCgExt -lSceSblSsMgr_stub -ltaihen_stub -lstdc++"

# Data lives at the vpk root (app0:/); saves/config go to ux0:data/instead.
# The embedded double quotes must survive to gcc, so they are literal in the
# variable value and $DEFS is expanded unquoted (no eval) at the call site.
DEFS='-Dunix -D_USE_UNPACK -D_USE_SDL -DSTEAD_PATH="stead/" -DTHEMES_PATH="themes/" -DGAMES_PATH="games/" -DLANG_PATH="lang/" -DICON_PATH="icon/"'
DEFS="$DEFS -DVERSION=\"$VERSION\""
INC="-Isrc -Isrc/instead $CFLAGS"

SRCS="SDL_gif.c SDL_gfxBlitFunc.c SDL_rotozoom.c config.c game.c graphics.c \
input.c noise1234.c ioapi.c main.c menu.c sound.c themes.c unpack.c unzip.c \
utils.c instead_bits.c instead_sprites.c instead_timer.c instead_sound.c \
instead_paths.c instead/instead.c instead/util.c instead/list.c \
instead/cache.c instead/idf.c instead/tinymt32.c instead/lfs.c unix.c"

echo ">> compiling ($VERSION)"
OBJS=""
for s in $SRCS; do
	o="$OBJ/$(echo "$s" | tr / _).o"
	# $DEFS and $INC intentionally unquoted for word-splitting.
	arm-vita-eabi-gcc -c $DEFS $INC -O2 -ffast-math "src/$s" -o "$o"
	OBJS="$OBJS $o"
done

echo ">> linking"
arm-vita-eabi-gcc -Wl,-q $OBJS -o "$BUILD/instead.elf" $LIBS $EXTRA_LIBS

echo ">> making eboot.bin"
arm-vita-eabi-strip -g "$BUILD/instead.elf"
vita-elf-create "$BUILD/instead.elf" "$BUILD/instead.velf"
vita-make-fself -s "$BUILD/instead.velf" "$BUILD/eboot.bin"

echo ">> making param.sfo"
vita-mksfoex -s TITLE_ID="$TITLEID" "$TITLE" "$BUILD/param.sfo"

# LiveArea icon (128x128). A prebuilt one ships next to this script.
ICON_ARG=""
if [ -f contrib/vita/icon0.png ]; then
	ICON_ARG="--add contrib/vita/icon0.png=sce_sys/icon0.png"
fi

echo ">> packing vpk"
# shellcheck disable=SC2086
vita-pack-vpk -s "$BUILD/param.sfo" -b "$BUILD/eboot.bin" \
	$ICON_ARG \
	--add stead=stead \
	--add themes=themes \
	--add lang=lang \
	--add games=games \
	--add icon=icon \
	"$BUILD/INSTEAD.vpk"

echo ">> done: $BUILD/INSTEAD.vpk"
ls -la "$BUILD/INSTEAD.vpk"
