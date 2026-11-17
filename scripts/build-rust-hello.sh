#!/usr/bin/env bash
# Builds the no_std Rust hello world into a PS4 eboot.bin and an installable PKG.
# Requires: source env.sh from setup-toolchain.sh, plus rustup nightly with rust-src:
#   rustup toolchain install nightly --profile minimal --component rust-src
set -euo pipefail

: "${OO_PS4_TOOLCHAIN:?source env.sh first}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/rust-hello"

export RUSTFLAGS="-C force-unwind-tables=yes \
 -C link-arg=--no-gc-sections \
 -C link-arg=--script -C link-arg=$OO_PS4_TOOLCHAIN/link.x \
 -C link-arg=-pie -C link-arg=-L$OO_PS4_TOOLCHAIN/lib \
 -C link-arg=-lc -C link-arg=-lkernel \
 -C link-arg=$OO_PS4_TOOLCHAIN/lib/crt1.o"

cargo +nightly build --target ps4.json -Z build-std=core -Z json-target-spec

ELF=target/ps4/debug/ps4-hello-rust
$OO_PS4_TOOLCHAIN/bin/linux/create-fself -in="$ELF" -out="$ELF.oelf" \
  --eboot eboot-rust.bin --paid 0x3800000000000011

echo "==> eboot-rust.bin built"

TID=RUST00001
CID=IV0000-RUST00001_00-PS4RUSTHELLO0001
PT=$OO_PS4_TOOLCHAIN/bin/linux/PkgTool.Core
PKGDIR="$ROOT/rust-hello/pkg"
rm -rf "$PKGDIR"; mkdir -p "$PKGDIR/sce_sys"
cp eboot-rust.bin "$PKGDIR/eboot.bin"
cp "$ROOT/assets/icon0.png" "$PKGDIR/sce_sys/icon0.png" 2>/dev/null || true

$PT sfo_new "$PKGDIR/sce_sys/param.sfo"
$PT sfo_setentry "$PKGDIR/sce_sys/param.sfo" APP_TYPE --type Integer --maxsize 4 --value 1
$PT sfo_setentry "$PKGDIR/sce_sys/param.sfo" APP_VER --type Utf8 --maxsize 8 --value '1.00'
$PT sfo_setentry "$PKGDIR/sce_sys/param.sfo" ATTRIBUTE --type Integer --maxsize 4 --value 0
$PT sfo_setentry "$PKGDIR/sce_sys/param.sfo" CATEGORY --type Utf8 --maxsize 4 --value 'gd'
$PT sfo_setentry "$PKGDIR/sce_sys/param.sfo" CONTENT_ID --type Utf8 --maxsize 48 --value "$CID"
$PT sfo_setentry "$PKGDIR/sce_sys/param.sfo" DOWNLOAD_DATA_SIZE --type Integer --maxsize 4 --value 0
$PT sfo_setentry "$PKGDIR/sce_sys/param.sfo" SYSTEM_VER --type Integer --maxsize 4 --value 0
$PT sfo_setentry "$PKGDIR/sce_sys/param.sfo" TITLE --type Utf8 --maxsize 128 --value 'PS4 Rust Hello'
$PT sfo_setentry "$PKGDIR/sce_sys/param.sfo" TITLE_ID --type Utf8 --maxsize 12 --value "$TID"
$PT sfo_setentry "$PKGDIR/sce_sys/param.sfo" VERSION --type Utf8 --maxsize 8 --value '1.00'

$OO_PS4_TOOLCHAIN/bin/linux/create-gp4 -out "$PKGDIR/pkg.gp4" \
  --content-id="$CID" --files "eboot.bin sce_sys/param.sfo sce_sys/icon0.png"

( cd "$PKGDIR" && $PT pkg_build pkg.gp4 . )
echo "==> PKG: $PKGDIR/$CID.pkg"
