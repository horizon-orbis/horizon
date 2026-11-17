# PS4 Homebrew + Rust — Sandbox Build Notes

Goal: port `0CYBER/horizon-free` (Rust Minecraft rewrite, wgpu 30) to PS4 using
OpenOrbis + the RADV **Vulkan** stack from `Rerence1016/CyreneLauncher`
(mesa-orbis / lwjgl-orbis / orbis-compat / orbis-porting-kit).

## Status

- [x] C++ pipeline: hello_world sample -> `hello_world.elf` -> `eboot.bin` (SCE 0xFE10)
- [x] **Rust -> PS4**: `no_std` Rust binary -> ELF -> `eboot-rust.bin` (SCE 0xFE10)
- [x] Installable PKG: `ps4-rust/pkg/IV0000-RUST00001_00-PS4RUSTHELLO0001.pkg`
      (writes `/data/rust_hello.txt` on console as a test marker)
- [ ] Vulkan (RADV) triangle in Rust via lwjgl-orbis platform PRX
- [ ] wgpu-hal on PS4 Vulkan
- [ ] horizon-free port

## Environment (recreate with source /workspace/env.sh)

- SDK: OpenOrbis v0.5.2 tarball -> `/workspace/OpenOrbisSDK` (`OO_PS4_TOOLCHAIN`)
- clang/lld: Debian trixie `llvm-toolchain-19` debs (clang-19, libclang-cpp19,
  libllvm19, lld-19, llvm-19-linker-tools) + runtime libs (libedit2, libz3-4,
  libxml2 2.12, libssl1.1 for PkgTool) extracted via `dpkg -x` -> `/workspace/llvm-root`
- PATH wrappers: `/workspace/tools-bin` (clang, clang++, ld.lld, llvm-ar, llvm-nm)
- Downloads land in `/workspace/downloads` (curl/wget blocked; use python urllib;
  `git clone` works; GitHub REST API is rate-limited)
- PkgTool.Core needs `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1` and libssl1.1 in
  LD_LIBRARY_PATH
- rustc: stable 1.99.1 + nightly (rust-src) for `-Z build-std`

## Rust -> PS4 recipe

Target spec: `/workspace/ps4-rust/ps4.json`
(llvm-target `x86_64-pc-freebsd12-elf`, gnu-lld flavor, PIE, panic=abort)

```
RUSTFLAGS="-C force-unwind-tables=yes -C link-arg=--no-gc-sections \
  -C link-arg=--script -C link-arg=$OO_PS4_TOOLCHAIN/link.x \
  -C link-arg=-pie -C link-arg=-L$OO_PS4_TOOLCHAIN/lib \
  -C link-arg=-lc -C link-arg=-lkernel \
  -C link-arg=$OO_PS4_TOOLCHAIN/lib/crt1.o"
cargo +nightly build --target ps4.json -Z build-std=core -Z json-target-spec
create-fself -in=<elf> -out=<oelf> --eboot eboot.bin --paid 0x3800000000000011
```

Gotchas found:
- `-C force-unwind-tables=yes` required or create-fself segfaults (no GNU_EH_FRAME)
- `-C link-arg=--no-gc-sections` required or `.data.sce_process_param` is dropped
  and create-fself nil-derefs (OELFGenProgramHeaders.go firstDataSection)
- `#![no_main]` + `#[no_mangle] extern "C" fn main(argc, argv)`; crt1.o calls main
- nightly required for JSON target specs (`-Z json-target-spec`) and build-std

## PKG recipe

PkgTool.Core verbs: sfo_new / sfo_setentry / pkg_build; create-gp4 needs
`--content-id` exactly 36 chars (e.g. `IV0000-RUST00001_00-PS4RUSTHELLO0001`).
right.sprx not needed for homebrew PKGs.

## Vulkan path (from CyreneLauncher docs)

- `graphics-probe/docs/MINECRAFT-VULKAN.md`: RADV compiled for PS4 (NEO GPU profile,
  patches 0013/0016/0017/0019/0020/0021/0032/0033/0047/0048...), exports
  `vkGetInstanceProcAddr` from `liborbis_lwjgl_platform.so`; WSI =
  VK_EXT_headless_surface + VideoOut; GL and Vulkan cannot own scanout simultaneously.
- Sibling repos (pinned in repositories.lock.json):
  - https://github.com/CyreneLauncher/mesa-orbis
  - https://github.com/CyreneLauncher/lwjgl-orbis
  - https://github.com/CyreneLauncher/orbis-runtime-support
  - https://github.com/orbis-ports/orbis-compat
  - https://github.com/orbis-ports/orbis-porting-kit
- horizon-free uses wgpu 30.0.1 (vendored wgpu-hal) + winit 0.30; needs
  Vulkan 1.2 + dynamic rendering + push descriptors + sync2 (RADV provides these).
- Plan: ash loads entry point from PRX export (no libvulkan.so loader on PS4);
  patch vendored wgpu-hal for headless-surface VideoOut presentation; replace winit
  with PS4 event loop + DualSense input.

## On-console test (user)

1. Install `IV0000-RUST00001_00-PS4RUSTHELLO0001.pkg` with the package installer.
2. Launch "PS4 Rust Hello". It shows nothing on screen by design (no VideoOut yet).
3. Verify via FTP: `/data/rust_hello.txt` contains "Rust on PS4 works!".
