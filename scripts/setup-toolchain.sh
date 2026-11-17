#!/usr/bin/env bash
# Sets up the OpenOrbis PS4 SDK + clang/lld 19 in a user-local prefix (no root needed).
# Tested on Debian 13 (trixie); adapt package versions for other distros.
set -euo pipefail

PREFIX="${1:-$HOME/ps4-dev}"
mkdir -p "$PREFIX/downloads" "$PREFIX/OpenOrbisSDK" "$PREFIX/llvm-root"

cd "$PREFIX/downloads"

echo "==> Downloading OpenOrbis SDK v0.5.2 (Linux parts)"
curl -L -o v0.5.2.tar.gz \
  https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain/releases/download/v0.5.2/v0.5.2.tar.gz
tar -xzf v0.5.2.tar.gz -C "$PREFIX/OpenOrbisSDK" \
  --strip-components=2 \
  OpenOrbis/PS4Toolchain/bin/linux \
  OpenOrbis/PS4Toolchain/include \
  OpenOrbis/PS4Toolchain/lib \
  OpenOrbis/PS4Toolchain/scripts \
  OpenOrbis/PS4Toolchain/LICENSE \
  OpenOrbis/PS4Toolchain/link.x

echo "==> Downloading Debian LLVM 19 debs (clang + lld)"
POOL=http://deb.debian.org/debian/pool/main/l/llvm-toolchain-19/
DEBS=(
  clang-19_19.1.7-3+b1_amd64.deb
  libclang-cpp19_19.1.7-3+b1_amd64.deb
  libllvm19_19.1.7-3+b1_amd64.deb
  lld-19_19.1.7-3+b1_amd64.deb
  llvm-19-linker-tools_19.1.7-3+b1_amd64.deb
)
for d in "${DEBS[@]}"; do curl -L -o "$d" "$POOL$d"; dpkg -x "$d" "$PREFIX/llvm-root"; done

echo "==> Downloading runtime libs (libedit, libz3, libxml2, libssl1.1)"
curl -L -o libedit2.deb http://deb.debian.org/debian/pool/main/libe/libedit/libedit2_3.1-20250104-1_amd64.deb
curl -L -o libz3-4.deb http://deb.debian.org/debian/pool/main/z/z3/libz3-4_4.8.12-3.1_amd64.deb
curl -L -o libxml2.deb http://deb.debian.org/debian/pool/main/libx/libxml2/libxml2_2.12.7+dfsg+really2.9.14-2.1+deb13u3_amd64.deb
curl -L -o libssl1.1.deb http://deb.debian.org/debian/pool/main/o/openssl/libssl1.1_1.1.1w-0+deb11u1_amd64.deb
for d in libedit2.deb libz3-4.deb libxml2.deb libssl1.1.deb; do dpkg -x "$d" "$PREFIX/llvm-root"; done

echo "==> Creating bin wrappers"
mkdir -p "$PREFIX/bin"
for t in clang clang++ ld.lld llvm-ar llvm-nm; do
  ln -sf "$PREFIX/llvm-root/usr/lib/llvm-19/bin/$t" "$PREFIX/bin/$t"
done

cat > "$PREFIX/env.sh" <<EOF
export OO_PS4_TOOLCHAIN=$PREFIX/OpenOrbisSDK
export PATH=$PREFIX/bin:\$PATH
export LD_LIBRARY_PATH=$PREFIX/llvm-root/usr/lib/llvm-19/lib:$PREFIX/llvm-root/usr/lib/x86_64-linux-gnu\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
EOF

echo "==> Done. Source it with:  source $PREFIX/env.sh"
